var circuit, monitor, monitorview, iopanel, paper;
var start = $("button[name=start]");
var stop = $("button[name=stop]");
var papers = {};
const fixed = function (fixed) {
  Object.values(papers).forEach((p) => p.fixed(fixed));
};
const loadCircuit = function (json) {
  circuit = new digitaljs.Circuit(json);
  monitor = new digitaljs.Monitor(circuit);
  monitorview = new digitaljs.MonitorView({
    model: monitor,
    el: $("#monitor"),
  });
  iopanel = new digitaljs.IOPanelView({ model: circuit, el: $("#iopanel") });
  circuit.on("new:paper", function (paper) {
    paper.fixed($("input[name=fixed]").prop("checked"));
    papers[paper.cid] = paper;
    paper.on("element:pointerdblclick", (cellView) => {
      window.digitaljsCell = cellView.model;
      console.info(
        "You can now access the doubly clicked gate as digitaljsCell in your WebBrowser console!"
      );
    });
  });
  circuit.on("changeRunning", () => {
    if (circuit.running) {
      start.prop("disabled", true);
      stop.prop("disabled", false);
    } else {
      start.prop("disabled", false);
      stop.prop("disabled", true);
    }
  });
  paper = circuit.displayOn($("#paper"));
  fixed($("input[name=fixed]").prop("checked"));
  circuit.on("remove:paper", function (paper) {
    delete papers[paper.cid];
  });
  circuit.start();
};
start.on("click", (e) => {
  circuit.start();
});
stop.on("click", (e) => {
  circuit.stop();
});
$("button[name=json]").on("click", (e) => {
  monitorview.shutdown();
  iopanel.shutdown();
  circuit.stop();
  const json = circuit.toJSON($("input[name=layout]").prop("checked"));
  console.log(json);
  loadCircuit(json);
});
$("input[name=fixed]").change(function () {
  fixed($(this).prop("checked"));
});
$("button[name=ppt_up]").on("click", (e) => {
  monitorview.pixelsPerTick *= 2;
});
$("button[name=ppt_down]").on("click", (e) => {
  monitorview.pixelsPerTick /= 2;
});
$("button[name=left]").on("click", (e) => {
  monitorview.live = false;
  monitorview.start -= monitorview._width / monitorview.pixelsPerTick / 4;
});
$("button[name=right]").on("click", (e) => {
  monitorview.live = false;
  monitorview.start += monitorview._width / monitorview.pixelsPerTick / 4;
});
$("button[name=live]").on("click", (e) => {
  monitorview.live = true;
});
$(window).ready(() => {
  $.getJSON("simulator.digitaljs", (circuit) => {
    loadCircuit(circuit);
  });
});
