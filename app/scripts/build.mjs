// Copia src/ a dist/. Es el paquete que se construye UNA vez y se publica en dev y prod.
// El config.json de cada ambiente lo escribe el pipeline al desplegar (scripts/escribir-config.mjs).
import { cp, mkdir, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const raiz = join(dirname(fileURLToPath(import.meta.url)), "..");
const origen = join(raiz, "src");
const destino = join(raiz, "dist");

await rm(destino, { recursive: true, force: true });
await mkdir(destino, { recursive: true });
await cp(origen, destino, { recursive: true });

console.log(`Sitio construido en ${destino}`);
