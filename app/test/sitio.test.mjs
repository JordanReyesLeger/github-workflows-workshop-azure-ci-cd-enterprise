import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { after, before, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

const raiz = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(raiz, "dist");

describe("sitio construido", () => {
  before(() => {
    execFileSync(process.execPath, [join(raiz, "scripts", "build.mjs")], { stdio: "ignore" });
  });

  test("incluye las páginas y recursos esperados", () => {
    for (const archivo of ["index.html", "404.html", "styles.css", "app.js"]) {
      assert.ok(existsSync(join(dist, archivo)), `falta dist/${archivo}`);
    }
  });

  test("index.html declara idioma, título y los elementos que llena el pipeline", async () => {
    const html = await readFile(join(dist, "index.html"), "utf8");
    assert.match(html, /<html lang="es">/);
    assert.match(html, /<title>[^<]+<\/title>/);
    for (const id of ["etiqueta-ambiente", "dato-ambiente", "dato-version", "dato-commit", "dato-fecha"]) {
      assert.ok(html.includes(`id="${id}"`), `falta el elemento #${id}`);
    }
  });

  test("los recursos referenciados por index.html existen", async () => {
    const html = await readFile(join(dist, "index.html"), "utf8");
    const referencias = [...html.matchAll(/(?:href|src)="([^"#:]+)"/g)].map((m) => m[1]);
    assert.ok(referencias.length > 0);
    for (const ref of referencias) {
      assert.ok(existsSync(join(dist, ref)), `index.html referencia ${ref}, que no existe en dist/`);
    }
  });

  test("no se publican secretos ni archivos de configuración local", () => {
    for (const archivo of [".env", "package.json", "tfplan"]) {
      assert.ok(!existsSync(join(dist, archivo)), `dist/${archivo} no debe publicarse`);
    }
  });
});

describe("escribir-config", () => {
  let carpeta;

  before(async () => {
    carpeta = await mkdtemp(join(tmpdir(), "config-"));
  });

  after(async () => {
    await rm(carpeta, { recursive: true, force: true });
  });

  test("genera config.json con ambiente, versión y commit corto", async () => {
    execFileSync(
      process.execPath,
      [join(raiz, "scripts", "escribir-config.mjs"), "dev", "1.2.3", "0123456789abcdef", carpeta],
      { stdio: "ignore" },
    );
    const config = JSON.parse(await readFile(join(carpeta, "config.json"), "utf8"));
    assert.equal(config.ambiente, "dev");
    assert.equal(config.version, "1.2.3");
    assert.equal(config.commit, "0123456");
    assert.ok(!Number.isNaN(Date.parse(config.publicado)));
  });

  test("falla si faltan argumentos", () => {
    assert.throws(() =>
      execFileSync(process.execPath, [join(raiz, "scripts", "escribir-config.mjs"), "dev"], { stdio: "ignore" }),
    );
  });
});
