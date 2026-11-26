import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

const page = (path: string) => fileURLToPath(new URL(path, import.meta.url));

// 전체 앱과 피처별 데모를 각각의 페이지로 빌드한다. 데모 페이지 번들에는 그 피처의 뷰만 들어간다.
export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      input: {
        app: page("./index.html"),
        loggedOut: page("./features/logged-out/demo.html"),
        loggedIn: page("./features/logged-in/demo.html"),
        todoList: page("./features/todo-list/demo.html"),
        todoDetail: page("./features/todo-detail/demo.html"),
        writeRequestSpike: page("./spikes/write-request.html"),
      },
    },
  },
});
