// Lee config.json, que escribe el pipeline en cada despliegue (no vive en el código).
async function cargarConfiguracion() {
  const respuesta = await fetch("config.json", { cache: "no-store" });
  if (!respuesta.ok) {
    throw new Error(`config.json respondió ${respuesta.status}`);
  }
  return respuesta.json();
}

function mostrar(config) {
  const etiqueta = document.getElementById("etiqueta-ambiente");
  etiqueta.textContent = config.ambiente;
  etiqueta.dataset.ambiente = config.ambiente;
  etiqueta.hidden = false;

  document.getElementById("dato-ambiente").textContent = config.ambiente;
  document.getElementById("dato-version").textContent = config.version;
  document.getElementById("dato-commit").textContent = config.commit;
  document.getElementById("dato-fecha").textContent = config.publicado;
}

cargarConfiguracion()
  .then(mostrar)
  .catch(() => {
    document.getElementById("dato-ambiente").textContent = "sin config.json (ejecución local)";
  });
