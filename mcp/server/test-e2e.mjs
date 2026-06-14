import net from "node:net";
import { spawn } from "node:child_process";

// Puerto configurable para no chocar con un editor de Godot abierto en 9080.
const PORT = parseInt(process.env.TEST_PORT || "9080", 10);

// Falso Godot: responde a cualquier comando
const fake = net.createServer((sock) => {
  let buf = "";
  sock.on("data", (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, i);
      buf = buf.slice(i + 1);
      const msg = JSON.parse(line);
      console.log("[fake-godot] recibido:", msg.command);
      if (msg.command === "get_errors") {
        sock.write(JSON.stringify({ id: msg.id, ok: true, result: { count: 0, entries: [] } }) + "\n");
      } else if (msg.command === "runtime_get_scene_tree") {
        sock.write(
          JSON.stringify({ id: msg.id, ok: false, error: "El juego no está en ejecución. Lánzalo con godot_run_scene primero." }) + "\n"
        );
      } else {
        sock.write(JSON.stringify({ id: msg.id, ok: true, result: { pong: true, godot_version: "4.6-test", project: "Demo" } }) + "\n");
      }
    }
  });
});

const EXPECTED_MIN_TOOLS = 100; // 42 originales + 32 Fase 1 + 26 Fase 2
let failures = 0;

fake.listen(PORT, "127.0.0.1", () => {
  const child = spawn("node", ["index.js"], {
    stdio: ["pipe", "pipe", "inherit"],
    env: { ...process.env, GODOT_PORT: String(PORT) },
  });
  let out = "";
  child.stdout.on("data", (d) => {
    out += d;
    const lines = out.split("\n");
    out = lines.pop();
    for (const line of lines) {
      if (!line.trim()) continue;
      let m;
      try {
        m = JSON.parse(line);
      } catch {
        continue;
      }
      if (m.id === 1) {
        child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");
        child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }) + "\n");
      }
      if (m.id === 2) {
        const tools = m.result.tools.map((t) => t.name);
        console.log(`[test] tools registradas: ${tools.length}`);
        if (tools.length < EXPECTED_MIN_TOOLS) {
          console.log(`FAIL: se esperaban >= ${EXPECTED_MIN_TOOLS} tools`);
          failures++;
        }
        for (const required of [
          "godot_get_errors", "runtime_get_scene_tree", "input_sequence", "runtime_screenshot",
          "godot_create_particles", "godot_add_audio_bus", "godot_create_animation_tree", "godot_set_theme_stylebox",
        ]) {
          if (!tools.includes(required)) {
            console.log(`FAIL: falta la tool ${required}`);
            failures++;
          }
        }
        child.stdin.write(
          JSON.stringify({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "godot_get_errors", arguments: {} } }) + "\n"
        );
      }
      if (m.id === 3) {
        if (m.result.isError) {
          console.log("FAIL: godot_get_errors devolvió error");
          failures++;
        } else {
          console.log("[test] godot_get_errors OK");
        }
        child.stdin.write(
          JSON.stringify({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "runtime_get_scene_tree", arguments: {} } }) + "\n"
        );
      }
      if (m.id === 4) {
        const text = JSON.stringify(m.result.content);
        if (!m.result.isError || !text.includes("no está en ejecución")) {
          console.log("FAIL: runtime_get_scene_tree debía devolver error accionable, recibido:", text);
          failures++;
        } else {
          console.log("[test] error accionable de runtime OK");
        }
        console.log(failures === 0 ? "TEST OK" : `TEST FAIL (${failures})`);
        child.kill();
        fake.close();
        process.exit(failures === 0 ? 0 : 1);
      }
    }
  });
  child.stdin.write(
    JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "test", version: "1.0" } } }) + "\n"
  );
});
setTimeout(() => {
  console.log("TIMEOUT");
  process.exit(1);
}, 15000);
