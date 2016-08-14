import numpy

from oasys.widgets import widget
from PyMca5.PyMcaGui.plotting.PlotWindow import PlotWindow

from orangecontrib.xrayserver.util.xrayserver_util import HttpManager, ShowTextDialog, XRayServerPlot
from orangecontrib.xrayserver.widgets.xrayserver.list_utility import ListUtility


class XrayServerWidget(widget.OWWidget):
    plot_canvas = []

    def get_lines(self):
        return ListUtility.get_list("waves")

    def help_lines(self):
        ShowTextDialog.show_text("Help Waves", ListUtility.get_help("waves"), width=350, parent=self)

    def get_crystals(self):
        return ListUtility.get_list("crystals")

    def help_crystals(self):
        ShowTextDialog.show_text("Help Crystals", ListUtility.get_help("crystals"), parent=self)

    def get_others(self):
        return ListUtility.get_list("amorphous+atoms")

    def help_others(self):
        ShowTextDialog.show_text("Help Others", ListUtility.get_help("amorphous+atoms"), parent=self)


    def get_parameters_from_form(self, form):
        parameters = {}

        for row in form:
            if "input" in row and "hidden" in row:
                temp = (row.split("name=\"")[1]).split("\"")
                key = temp[0]

                if len(temp) == 2:
                    value = ((temp[1].split("value=")[1]).split(">")[0]).strip()
                else:
                    value = temp[2].strip()

                parameters.update({key : value})

        return parameters

    def get_data_file_from_response(self, response):
        rows = response.split("\n")

        job_id = None
        data = None

        for row in rows:
            if "Job ID" in row:
                job_id = (row.split("<b>"))[1].split("</b>")[0]

            if not job_id is None:
                if not job_id+".png" in response:
                    raise XrayServerException(response)

                if job_id+".dat" in row:
                    data = HttpManager.send_xray_server_direct_request((row.split("href=\"")[1]).split("\"")[0])

        if not data is None:
            rows = data.split("\r\n")

            x = []
            y = []

            for row in rows:
                temp = row.strip().split(" ")

                if len(temp) > 1:
                    x.append(float(temp[0].strip()))
                    y.append(float(temp[len(temp)-1].strip()))

            if numpy.sum(y) == 0: raise Exception("No data to plot: all Y column values=0")

            return x, y
        else:
            if job_id is None:
                raise Exception("Job ID not present")
            else:
                raise Exception("Empty data file: " + job_id + ".dat")

    def get_plots_from_form(self, application, form):
        response = HttpManager.send_xray_server_request_POST(application, self.get_parameters_from_form(form))

        return self.get_data_file_from_response(response)


    def plot_histo(self, x, y, progressBarValue, tabs_canvas_index, plot_canvas_index, title="", xtitle="", ytitle=""):
        if self.plot_canvas[plot_canvas_index] is None:
            self.plot_canvas[plot_canvas_index] = PlotWindow(roi=False, control=False, position=False, plugins=False)
            self.plot_canvas[plot_canvas_index].setDefaultPlotLines(True)
            self.plot_canvas[plot_canvas_index].setActiveCurveColor(color='darkblue')
            self.plot_canvas[plot_canvas_index].setYAxisLogarithmic(True)

            self.tabs[tabs_canvas_index].layout().addWidget(self.plot_canvas[plot_canvas_index])

        XRayServerPlot.plot_histo(self.plot_canvas[plot_canvas_index], x, y, title, xtitle, ytitle)

        self.progressBarSet(progressBarValue)

class XrayServerException(Exception):

    response = None

    def __init__(self, response):
        super().__init__()

        self.response = XrayServerException.clear_response(response)

    @classmethod
    def clear_response(cls, response):
        return response.split("<p><b>Download ZIPped results:")[0] + "\n</body></html>"