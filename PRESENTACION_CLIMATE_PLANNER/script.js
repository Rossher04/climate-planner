/* ===== Climate Planner — lógica de la presentación ===== */

// 1) Inicializar Reveal.js
Reveal.initialize({
  hash: true,
  controls: true,         // flechas en pantalla
  progress: true,         // barra de progreso
  slideNumber: 'c/t',     // número de diapositiva (actual/total)
  center: true,
  transition: 'fade',     // transición suave entre slides
  transitionSpeed: 'default',
  backgroundTransition: 'fade',
  keyboard: true,         // navegación con teclado
  touch: true,            // navegación táctil / mouse
});

// 2) Modo oscuro (botón 🌙 o tecla D)
const themeBtn = document.getElementById('themeBtn');
function toggleTheme() {
  const dark = document.body.classList.toggle('theme-dark');
  themeBtn.textContent = dark ? '☀️' : '🌙';
  applyChartTheme(dark);
}
themeBtn.addEventListener('click', toggleTheme);
document.addEventListener('keydown', (e) => {
  if (e.key === 'd' || e.key === 'D') toggleTheme();
});

// 3) Pantalla completa (botón ⛶)
document.getElementById('fsBtn').addEventListener('click', () => {
  if (document.fullscreenElement) {
    document.exitFullscreen();
  } else {
    document.documentElement.requestFullscreen().catch(() => {});
  }
});

// 4) Gráfica de regresión lineal (Chart.js) — se crea al llegar a la slide
let regChart = null;

function buildRegressionChart() {
  const canvas = document.getElementById('regChart');
  if (!canvas || regChart) return;

  // Serie real (7 máximas previas) y recta y = 0.2821x + 17.40
  const puntos = [
    { x: 1, y: 17.9 }, { x: 2, y: 18.9 }, { x: 3, y: 18.0 },
    { x: 4, y: 17.2 }, { x: 5, y: 17.9 }, { x: 6, y: 19.9 }, { x: 7, y: 19.9 },
  ];
  const m = 0.2821, b = 17.40;
  const recta = [{ x: 1, y: m * 1 + b }, { x: 7, y: m * 7 + b }];

  regChart = new Chart(canvas.getContext('2d'), {
    type: 'scatter',
    data: {
      datasets: [
        {
          label: 'Temperatura máx (°C)',
          data: puntos,
          backgroundColor: '#4A90E2',
          pointRadius: 7,
          pointHoverRadius: 9,
        },
        {
          label: 'Regresión  y = 0.2821x + 17.40',
          type: 'line',
          data: recta,
          borderColor: '#E2725B',
          borderWidth: 3,
          pointRadius: 0,
          fill: false,
          tension: 0,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 900 },
      scales: {
        x: { title: { display: true, text: 'Día (1–7)' }, min: 0.5, max: 7.5, ticks: { stepSize: 1 } },
        y: { title: { display: true, text: 'Temperatura (°C)' }, suggestedMin: 16, suggestedMax: 21 },
      },
      plugins: { legend: { position: 'top' } },
    },
  });
  applyChartTheme(document.body.classList.contains('theme-dark'));
}

// Ajusta los colores del chart según el tema
function applyChartTheme(dark) {
  if (!regChart) return;
  const tick = dark ? '#9FB0C0' : '#5A6B7B';
  const grid = dark ? 'rgba(159,176,192,.18)' : 'rgba(44,110,145,.12)';
  ['x', 'y'].forEach((axis) => {
    regChart.options.scales[axis].ticks.color = tick;
    regChart.options.scales[axis].grid.color = grid;
    regChart.options.scales[axis].title.color = tick;
  });
  regChart.options.plugins.legend.labels = { color: tick };
  regChart.update();
}

// Crear la gráfica cuando la diapositiva sea visible (evita tamaño 0)
Reveal.on('ready', (e) => { if (e.currentSlide.querySelector('#regChart')) buildRegressionChart(); });
Reveal.on('slidechanged', (e) => { if (e.currentSlide.querySelector('#regChart')) buildRegressionChart(); });
