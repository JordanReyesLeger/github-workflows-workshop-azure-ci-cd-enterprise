// Pide los datos del despliegue a la API de la propia app (/api/info).
async function cargarInformacion() {
  const respuesta = await fetch("api/info", { cache: "no-store" });
  if (!respuesta.ok) {
    throw new Error(`api/info respondió ${respuesta.status}`);
  }
  return respuesta.json();
}

function mostrar(info) {
  const etiqueta = document.getElementById("etiqueta-ambiente");
  etiqueta.textContent = info.ambiente;
  etiqueta.dataset.ambiente = info.ambiente;
  etiqueta.hidden = false;

  document.getElementById("dato-ambiente").textContent = info.ambiente;
  document.getElementById("dato-version").textContent = info.version;
  document.getElementById("dato-commit").textContent = info.commit;
  document.getElementById("dato-fecha").textContent = info.publicado;
  document.getElementById("dato-runtime").textContent = info.runtime;
}

cargarInformacion()
  .then(mostrar)
  .catch(() => {
    document.getElementById("dato-ambiente").textContent = "no se pudo leer /api/info";
  });
