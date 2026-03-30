(function() {
  function parseJson(value) {
    try {
      return JSON.parse(value || "[]");
    } catch (_error) {
      return [];
    }
  }

  function destroyChart(canvas) {
    if (canvas.codeSunsetChart) {
      canvas.codeSunsetChart.destroy();
      canvas.codeSunsetChart = null;
    }
  }

  function buildChart(canvas) {
    if (!window.Chart) {
      return;
    }

    destroyChart(canvas);

    var labels = parseJson(canvas.dataset.labels);
    var values = parseJson(canvas.dataset.values);

    if (!labels.length || !values.length) {
      return;
    }

    canvas.codeSunsetChart = new window.Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            data: values,
            borderColor: "#635bff",
            backgroundColor: "rgba(99, 91, 255, 0.10)",
            borderWidth: 2,
            fill: true,
            pointRadius: 0,
            pointHoverRadius: 4,
            pointHoverBackgroundColor: "#635bff",
            pointHoverBorderColor: "#ffffff",
            pointHoverBorderWidth: 2,
            tension: 0.35
          }
        ]
      },
      options: {
        animation: false,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: "#0f172a",
            displayColors: false,
            padding: 10,
            titleColor: "#f8fafc",
            bodyColor: "#e2e8f0",
            callbacks: {
              label: function(context) {
                var value = context.parsed.y || 0;
                return value + " hit" + (value === 1 ? "" : "s");
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            },
            border: {
              display: false
            },
            ticks: {
              color: "#6b7c93",
              maxRotation: 0,
              autoSkipPadding: 18,
              font: {
                size: 11
              }
            }
          },
          y: {
            beginAtZero: true,
            grid: {
              color: "rgba(15, 23, 42, 0.08)",
              drawBorder: false
            },
            border: {
              display: false
            },
            ticks: {
              color: "#6b7c93",
              precision: 0,
              font: {
                size: 11
              }
            }
          }
        }
      }
    });
  }

  function initializeCharts() {
    document.querySelectorAll("[data-code-sunset-usage-chart]").forEach(buildChart);
  }

  function teardownCharts() {
    document.querySelectorAll("[data-code-sunset-usage-chart]").forEach(destroyChart);
  }

  function copyText(value) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(value);
    }

    return new Promise(function(resolve, reject) {
      var textarea = document.createElement("textarea");
      textarea.value = value;
      textarea.setAttribute("readonly", "readonly");
      textarea.style.position = "absolute";
      textarea.style.left = "-9999px";
      document.body.appendChild(textarea);
      textarea.select();

      try {
        document.execCommand("copy");
        resolve();
      } catch (error) {
        reject(error);
      } finally {
        document.body.removeChild(textarea);
      }
    });
  }

  function bindCopyButtons() {
    document.querySelectorAll("[data-copy-target]").forEach(function(button) {
      if (button.dataset.copyBound === "true") {
        return;
      }

      button.dataset.copyBound = "true";
      button.addEventListener("click", function() {
        var target = document.getElementById(button.dataset.copyTarget);
        if (!target) {
          return;
        }

        var defaultLabel = button.dataset.copyDefaultLabel || button.textContent;
        var successLabel = button.dataset.copySuccessLabel || "Copied";

        copyText(target.textContent || "")
          .then(function() {
            button.textContent = successLabel;
            window.setTimeout(function() {
              button.textContent = defaultLabel;
            }, 1600);
          })
          .catch(function() {
            button.textContent = defaultLabel;
          });
      });
    });
  }

  document.addEventListener("DOMContentLoaded", initializeCharts);
  document.addEventListener("turbo:load", initializeCharts);
  document.addEventListener("DOMContentLoaded", bindCopyButtons);
  document.addEventListener("turbo:load", bindCopyButtons);
  document.addEventListener("turbo:before-cache", teardownCharts);
})();
