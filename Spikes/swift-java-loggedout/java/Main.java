import com.carti.login.*;
import org.swift.swiftkit.core.*;
import java.util.*;

// Compose 뷰 자리에 서는 JVM 쪽 구현. Swift 프로토콜 LoggedOutViewBridge를 직접 구현한다.
public class Main {
    static final List<String> rendered = new ArrayList<>();

    static class FakeLoggedOutView implements LoggedOutViewBridge {
        @Override public void render(LoggedOutViewState state) {
            rendered.add("error=" + state.getErrorMessage().orElse("-") + " loading=" + state.isLoading());
        }
    }

    public static void main(String[] args) {
        try (var arena = SwiftArena.ofConfined()) {
            var handle = LoggedOutScreenHandle.init(new FakeLoggedOutView(), arena);
            handle.activate();
            handle.send(LoggedOutViewAction.loginTapped("", arena));
            handle.send(LoggedOutViewAction.loginTapped("carti", arena));
            System.out.println("lastName=" + handle.lastName());
        }
        rendered.forEach(System.out::println);
        boolean ok = rendered.equals(List.of("error=- loading=false", "error=이름을 입력하세요 loading=false", "error=- loading=true"));
        System.out.println(ok ? "PASS" : "FAIL");
        if (!ok) System.exit(1);
    }
}
