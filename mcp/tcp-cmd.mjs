// Utilidad: envía un comando JSON al bridge de Godot y muestra la respuesta.
// Uso: node tcp-cmd.mjs <comando> ['{"json":"params"}'] [timeout_ms]
import net from "node:net";

const command = process.argv[2];
const params = process.argv[3] ? JSON.parse(process.argv[3]) : {};
const timeoutMs = parseInt(process.argv[4] || "15000", 10);

const s = net.createConnection(9080, "127.0.0.1", () => {
  s.write(JSON.stringify({ id: 1, command, params }) + "\n");
});
let buf = "";
s.on("data", (d) => {
  buf += d;
  const i = buf.indexOf("\n");
  if (i >= 0) {
    const msg = JSON.parse(buf.slice(0, i));
    // No volcar imágenes base64 enteras
    if (msg.result && msg.result.image_base64) {
      msg.result.image_base64 = `<${msg.result.image_base64.length} chars>`;
    }
    console.log(JSON.stringify(msg, null, 2));
    process.exit(msg.ok ? 0 : 1);
  }
});
s.on("error", (e) => {
  console.error("ERROR:", e.message);
  process.exit(2);
});
setTimeout(() => {
  console.error("TIMEOUT");
  process.exit(3);
}, timeoutMs);
