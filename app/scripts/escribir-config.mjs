// Genera dist/config.json con los datos del despliegue.
// Uso: node scripts/escribir-config.mjs <ambiente> <version> <commit> [carpeta]
import { writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const [ambiente, version, commit, carpeta] = process.argv.slice(2);

if (!ambiente || !version || !commit) {
  console.error("Uso: node scripts/escribir-config.mjs <ambiente> <version> <commit> [carpeta]");
  process.exit(1);
}

const raiz = join(dirname(fileURLToPath(import.meta.url)), "..");
const destino = resolve(carpeta ?? join(raiz, "dist"), "config.json");

const config = {
  ambiente,
  version,
  commit: commit.slice(0, 7),
  publicado: new Date().toISOString(),
};

await writeFile(destino, JSON.stringify(config, null, 2) + "\n");
console.log(`Escrito ${destino}`);
console.log(config);
