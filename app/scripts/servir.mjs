// Servidor local mínimo para ver el sitio: npm run build && npm start
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { dirname, extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const raiz = join(dirname(fileURLToPath(import.meta.url)), "..", "dist");
const puerto = Number(process.env.PORT ?? 8080);
const tipos = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json",
};

createServer(async (peticion, respuesta) => {
  const ruta = new URL(peticion.url, "http://localhost").pathname;
  const archivo = normalize(join(raiz, ruta === "/" ? "index.html" : ruta));

  if (!archivo.startsWith(raiz)) {
    respuesta.writeHead(403).end("Prohibido");
    return;
  }

  try {
    const contenido = await readFile(archivo);
    respuesta.writeHead(200, { "Content-Type": tipos[extname(archivo)] ?? "application/octet-stream" });
    respuesta.end(contenido);
  } catch {
    respuesta.writeHead(404).end("No encontrado");
  }
}).listen(puerto, () => console.log(`http://localhost:${puerto}`));
