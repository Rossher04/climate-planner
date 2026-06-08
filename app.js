const screens = document.querySelectorAll(".screen");
const openButtons = document.querySelectorAll("[data-open]");
const navButtons = document.querySelectorAll(".nav-item[data-view]");
const panels = document.querySelectorAll("[data-view-panel]");
const viewTitle = document.querySelector("#view-title");

const titles = {
  home: "Resumen",
  locations: "Ubicaciones",
  activities: "Actividades",
  pending: "Pendientes",
  stats: "Estadistica",
};

const temperatures = [22, 24, 23, 25, 24, 26, 27];

function setScreen(name) {
  screens.forEach((screen) => {
    screen.classList.toggle("is-active", screen.dataset.screen === name);
  });
}

function setView(name) {
  navButtons.forEach((button) => {
    button.classList.toggle("is-selected", button.dataset.view === name);
  });

  panels.forEach((panel) => {
    panel.classList.toggle("is-visible", panel.dataset.viewPanel === name);
  });

  viewTitle.textContent = titles[name];

  if (name === "stats") {
    drawTrendChart();
  }
}

function mean(values) {
  return values.reduce((total, value) => total + value, 0) / values.length;
}

function median(values) {
  const ordered = [...values].sort((a, b) => a - b);
  const middle = Math.floor(ordered.length / 2);
  return ordered[middle];
}

function mode(values) {
  const counts = new Map();
  values.forEach((value) => counts.set(value, (counts.get(value) || 0) + 1));
  return [...counts.entries()].sort((a, b) => b[1] - a[1])[0][0];
}

function linearRegression(values) {
  const points = values.map((y, index) => ({ x: index + 1, y }));
  const n = points.length;
  const sumX = points.reduce((total, point) => total + point.x, 0);
  const sumY = points.reduce((total, point) => total + point.y, 0);
  const sumXY = points.reduce((total, point) => total + point.x * point.y, 0);
  const sumXX = points.reduce((total, point) => total + point.x * point.x, 0);
  const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  const intercept = (sumY - slope * sumX) / n;
  return { slope, intercept };
}

function drawTrendChart() {
  const canvas = document.querySelector("#trend-chart");
  const ctx = canvas.getContext("2d");
  const width = canvas.width;
  const height = canvas.height;
  const padding = 28;
  const min = Math.min(...temperatures) - 1;
  const max = Math.max(...temperatures) + 1;
  const { slope, intercept } = linearRegression(temperatures);

  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#fbfdfe";
  ctx.fillRect(0, 0, width, height);

  ctx.strokeStyle = "#dfe7ec";
  ctx.lineWidth = 1;
  for (let i = 0; i < 4; i += 1) {
    const y = padding + i * ((height - padding * 2) / 3);
    ctx.beginPath();
    ctx.moveTo(padding, y);
    ctx.lineTo(width - padding, y);
    ctx.stroke();
  }

  const toX = (day) => padding + ((day - 1) / 6) * (width - padding * 2);
  const toY = (temp) => height - padding - ((temp - min) / (max - min)) * (height - padding * 2);

  ctx.strokeStyle = "#2474a6";
  ctx.lineWidth = 3;
  ctx.beginPath();
  temperatures.forEach((temp, index) => {
    const x = toX(index + 1);
    const y = toY(temp);
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.stroke();

  temperatures.forEach((temp, index) => {
    ctx.fillStyle = "#ffffff";
    ctx.strokeStyle = "#2474a6";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(toX(index + 1), toY(temp), 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  });

  ctx.strokeStyle = "#d85c4a";
  ctx.lineWidth = 2;
  ctx.setLineDash([6, 5]);
  ctx.beginPath();
  ctx.moveTo(toX(1), toY(slope * 1 + intercept));
  ctx.lineTo(toX(7), toY(slope * 7 + intercept));
  ctx.stroke();
  ctx.setLineDash([]);

  ctx.fillStyle = "#6d7882";
  ctx.font = "11px Segoe UI";
  temperatures.forEach((_, index) => {
    ctx.fillText(String(index + 1), toX(index + 1) - 3, height - 8);
  });

  document.querySelector("#mean-value").textContent = `${mean(temperatures).toFixed(1)} C`;
  document.querySelector("#median-value").textContent = `${median(temperatures)} C`;
  document.querySelector("#mode-value").textContent = `${mode(temperatures)} C`;
  document.querySelector("#trend-label").textContent = slope >= 0 ? "Al alza" : "A la baja";
}

openButtons.forEach((button) => {
  button.addEventListener("click", () => setScreen(button.dataset.open));
});

navButtons.forEach((button) => {
  button.addEventListener("click", () => setView(button.dataset.view));
});

drawTrendChart();
