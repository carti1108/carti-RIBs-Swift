#if os(Android)
import Android
import AndroidLoginUI
import LoginShared
import RIBsAndroid

// Kotlin `com.carti.ribs.samples.swiftandroid.SwiftBridge`와 짝을 이루는 손으로 쓴 JNI 표면(ADR-0010).
// 문자열은 모두 UTF-8 byte[]로 주고받는다. JNI의 NewStringUTF는 "수정된 UTF-8"이라 이모지 같은 보조 평면 문자가 깨진다.
// 모든 진입점은 Android 메인 스레드에서 불린다고 가정하고 `MainActor.assumeIsolated`로 확인한다.

public typealias Env = UnsafeMutablePointer<JNIEnv?>

private let bridgeClassName = "com/carti/ribs/samples/swiftandroid/SwiftBridge"

/// 메인 스레드 전용 상태. `MainActor`로 격리한다.
@MainActor private var controller: AndroidLoginController?
@MainActor private var renderTarget: RenderTarget?
nonisolated(unsafe) private var javaVM: UnsafeMutablePointer<JavaVM?>?

/// Kotlin `SwiftBridge.onRender(byte[])`를 부르는 데 필요한 전역 참조.
/// JNI 전역 참조와 메서드 ID는 스레드 사이에서 써도 되는 핸들이다.
private struct RenderTarget: @unchecked Sendable {
    let bridgeClass: jclass
    let onRender: jmethodID
}

@_cdecl("JNI_OnLoad")
public func JNI_OnLoad(vm: UnsafeMutablePointer<JavaVM?>, reserved: UnsafeMutableRawPointer?) -> jint {
    javaVM = vm
    return jint(JNI_VERSION_1_6)
}

@_cdecl("Java_com_carti_ribs_samples_swiftandroid_SwiftBridge_nativeAttachMainLooper")
public func nativeAttachMainLooper(env: Env, thiz: jobject) -> jboolean {
    MainActor.assumeIsolated { AndroidMainLooper.attach() } ? jboolean(JNI_TRUE) : jboolean(JNI_FALSE)
}

@_cdecl("Java_com_carti_ribs_samples_swiftandroid_SwiftBridge_nativeStart")
public func nativeStart(env: Env, thiz: jobject, savedState: jbyteArray?, loginDelayMillis: jlong) -> jboolean {
    let saved = savedState.map { string(env, from: $0) }
    let target = makeRenderTarget(env)
    let restored = MainActor.assumeIsolated { () -> Bool in
        precondition(controller == nil, "SwiftBridge.start called twice without stop")
        renderTarget = target
        let clock = TaskSleepClock()
        let app = AndroidLoginController(
            authService: DelayedAuthService(delay: .milliseconds(loginDelayMillis), clock: clock),
            clock: clock,
            sink: sendToKotlin
        )
        controller = app
        return app.start(savedState: saved)
    }
    return restored ? jboolean(JNI_TRUE) : jboolean(JNI_FALSE)
}

@_cdecl("Java_com_carti_ribs_samples_swiftandroid_SwiftBridge_nativeDispatch")
public func nativeDispatch(env: Env, thiz: jobject, screenID: jlong, action: jbyteArray, argument: jbyteArray) -> jboolean {
    let action = string(env, from: action)
    let argument = string(env, from: argument)
    let handled = MainActor.assumeIsolated {
        controller?.dispatch(screenID: screenID, action: action, argument: argument) ?? false
    }
    return handled ? jboolean(JNI_TRUE) : jboolean(JNI_FALSE)
}

@_cdecl("Java_com_carti_ribs_samples_swiftandroid_SwiftBridge_nativeHandleBackPress")
public func nativeHandleBackPress(env: Env, thiz: jobject) -> jboolean {
    MainActor.assumeIsolated { controller?.handleBackPress() ?? false } ? jboolean(JNI_TRUE) : jboolean(JNI_FALSE)
}

@_cdecl("Java_com_carti_ribs_samples_swiftandroid_SwiftBridge_nativeSaveState")
public func nativeSaveState(env: Env, thiz: jobject) -> jbyteArray? {
    let saved = MainActor.assumeIsolated { controller?.saveState() }
    return saved.flatMap { byteArray(env, from: $0) }
}

@_cdecl("Java_com_carti_ribs_samples_swiftandroid_SwiftBridge_nativeStop")
public func nativeStop(env: Env, thiz: jobject) {
    let target = MainActor.assumeIsolated { () -> RenderTarget? in
        controller?.stop()
        controller = nil
        defer { renderTarget = nil }
        return renderTarget
    }
    if let target { env.pointee!.pointee.DeleteGlobalRef(env, target.bridgeClass) }
}

// MARK: - Kotlin 호출

private func makeRenderTarget(_ env: Env) -> RenderTarget {
    let jni = env.pointee!.pointee
    guard let localClass = jni.FindClass(env, bridgeClassName) else {
        preconditionFailure("JNI class not found: \(bridgeClassName)")
    }
    defer { jni.DeleteLocalRef(env, localClass) }
    guard let method = jni.GetStaticMethodID(env, localClass, "onRender", "([B)V"),
          let globalClass = jni.NewGlobalRef(env, localClass)
    else { preconditionFailure("JNI method not found: \(bridgeClassName).onRender([B)V") }
    return RenderTarget(bridgeClass: globalClass, onRender: method)
}

/// 렌더러가 트리를 그릴 때마다 메인 스레드에서 불린다.
@MainActor
private func sendToKotlin(_ tree: String) {
    guard let target = renderTarget, let env = currentEnv() else { return }
    guard let bytes = byteArray(env, from: tree) else { return }
    defer { env.pointee!.pointee.DeleteLocalRef(env, bytes) }
    var argument = jvalue(l: bytes)
    env.pointee!.pointee.CallStaticVoidMethodA(env, target.bridgeClass, target.onRender, &argument)
    if env.pointee!.pointee.ExceptionCheck(env) == jboolean(JNI_TRUE) {
        // Kotlin 예외를 삼키지 않는다. 내용을 logcat에 남기고 앱을 멈춘다.
        env.pointee!.pointee.ExceptionDescribe(env)
        preconditionFailure("SwiftBridge.onRender threw")
    }
}

/// 메인 스레드는 Java 스레드라 이미 붙어 있다. 붙지 않은 스레드면 nil.
private func currentEnv() -> Env? {
    guard let vm = javaVM else { return nil }
    var raw: UnsafeMutableRawPointer?
    guard vm.pointee!.pointee.GetEnv(vm, &raw, jint(JNI_VERSION_1_6)) == JNI_OK, let raw else { return nil }
    return raw.assumingMemoryBound(to: JNIEnv?.self)
}

// MARK: - UTF-8 변환

private func string(_ env: Env, from array: jbyteArray) -> String {
    let jni = env.pointee!.pointee
    let count = Int(jni.GetArrayLength(env, array))
    var bytes = [UInt8](repeating: 0, count: count)
    bytes.withUnsafeMutableBufferPointer { buffer in
        buffer.baseAddress.map { jni.GetByteArrayRegion(env, array, 0, jsize(count), UnsafeMutableRawPointer($0).assumingMemoryBound(to: jbyte.self)) }
    }
    return String(decoding: bytes, as: UTF8.self)
}

private func byteArray(_ env: Env, from text: String) -> jbyteArray? {
    let jni = env.pointee!.pointee
    let bytes = Array(text.utf8)
    guard let array = jni.NewByteArray(env, jsize(bytes.count)) else { return nil }
    bytes.withUnsafeBufferPointer { buffer in
        buffer.baseAddress.map { jni.SetByteArrayRegion(env, array, 0, jsize(bytes.count), UnsafeRawPointer($0).assumingMemoryBound(to: jbyte.self)) }
    }
    return array
}
#endif
