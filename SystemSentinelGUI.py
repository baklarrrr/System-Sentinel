import os
import sys
import logging
from PyQt6.QtWidgets import (
    QWidget,
    QVBoxLayout,
    QLabel,
    QTextEdit,
    QProgressBar,
    QPushButton,
    QMessageBox,
    QApplication,
    QDialog,
)
from PyQt6.QtGui import QIcon
from PyQt6.QtCore import QProcess
import subprocess

from log_helper import logger  # centralized logging
from report_generator import parse_log_dates
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure

def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS  # PyInstaller temporary folder
    except AttributeError:
        base_path = os.path.abspath(".")
    full_path = os.path.join(base_path, relative_path)
    if not os.path.exists(full_path):
        logger.error(f"Resource not found: {full_path}")
    return full_path


class ReportWindow(QDialog):
    def __init__(self, log_path: str, parent=None):
        super().__init__(parent)
        self.setWindowTitle("System Sentinel Report")
        self.resize(800, 600)
        layout = QVBoxLayout(self)

        self.logView = QTextEdit()
        self.logView.setReadOnly(True)
        layout.addWidget(self.logView)

        if os.path.exists(log_path):
            with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
                self.logView.setPlainText(f.read())
        else:
            self.logView.setPlainText(f"Log file not found: {log_path}")

        data = parse_log_dates(log_path)
        if data:
            times = sorted(data.keys())
            counts = [data[t] for t in times]
            fig = Figure(figsize=(6, 4))
            ax = fig.add_subplot(111)
            ax.plot(times, counts, marker='o')
            ax.set_title("Log Activity Over Time")
            ax.set_xlabel("Time")
            ax.set_ylabel("Entries")
            fig.autofmt_xdate()
            canvas = FigureCanvas(fig)
            layout.addWidget(canvas)
        else:
            layout.addWidget(QLabel("No data available for plotting."))

class MainWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("System Sentinel")
        icon_path = resource_path("SystemSentinel.ico")
        # Check if file exists; if not use a default empty QIcon
        if os.path.exists(icon_path):
            self.setWindowIcon(QIcon(icon_path))
        else:
            logger.warning("Icon file not found, using default icon.")
            self.setWindowIcon(QIcon())
        self.resize(600, 400)
        layout = QVBoxLayout()

        self.label = QLabel("System Sentinel: Cleaning Your System...")
        self.label.setStyleSheet("font-size: 18px;")
        layout.addWidget(self.label)

        self.logText = QTextEdit()
        self.logText.setReadOnly(True)
        layout.addWidget(self.logText)

        self.progressBar = QProgressBar()
        self.progressBar.setVisible(False)
        layout.addWidget(self.progressBar)

        self.runButton = QPushButton("Run System Sentinel")
        self.runButton.setStyleSheet("padding: 10px; font-size: 16px;")
        self.runButton.clicked.connect(self.run_sentinel)
        layout.addWidget(self.runButton)

        self.reportButton = QPushButton("Show Report")
        self.reportButton.setStyleSheet("padding: 10px; font-size: 16px;")
        self.reportButton.clicked.connect(self.show_report)
        layout.addWidget(self.reportButton)

        self.setLayout(layout)

        self.process = QProcess(self)
        self.process.readyReadStandardOutput.connect(self.handle_stdout)
        self.process.readyReadStandardError.connect(self.handle_stderr)
        self.process.finished.connect(self.process_finished)

        logger.info("MainWindow initialized.")

    def run_sentinel(self):
        self.logText.append("Starting System Sentinel...")
        self.progressBar.setVisible(True)
        self.runButton.setEnabled(False)
        logger.info("Starting System Sentinel...")
        script_path = resource_path("SystemSentinel.ps1")
        if not os.path.exists(script_path):
            QMessageBox.critical(self, "Error", f"SystemSentinel.ps1 not found at:\n{script_path}")
            self.runButton.setEnabled(True)
            self.progressBar.setVisible(False)
            logger.error(f"SystemSentinel.ps1 not found at: {script_path}")
            return

        logger.info(f"Running script: {script_path}")
        self.process.start("powershell.exe", ["-ExecutionPolicy", "Bypass", "-File", script_path])

    def handle_stdout(self):
        data = self.process.readAllStandardOutput().data().decode("utf8")
        self.logText.append(data)
        logger.debug(data.strip())

    def handle_stderr(self):
        data = self.process.readAllStandardError().data().decode("utf8")
        self.logText.append(f"ERROR: {data}")
        logger.error(data.strip())

    def process_finished(self):
        exit_code = self.process.exitCode()
        if exit_code == 0:
            self.logText.append("Module finished successfully.")
            # Let's assume this module is "Module A"
            self.modules["Module A"].setChecked(True)
            self.modules["Module A"].setStyleSheet("color: green; font-size: 16px;")
        else:
            self.logText.append("Module encountered errors.")
            self.modules["Module A"].setChecked(False)
            self.modules["Module A"].setStyleSheet("color: red; font-size: 16px;")
        self.runButton.setEnabled(True)
        self.progressBar.setVisible(False)
        logger.info("Processing finished.")

    def show_report(self):
        log_path = resource_path("build_scan_log.txt")
        if os.path.exists(log_path):
            dialog = ReportWindow(log_path, self)
            dialog.exec()
        else:
            QMessageBox.information(self, "Report Not Found", f"No generated log found at:\n{log_path}")

if __name__ == '__main__':
    try:
        app = QApplication(sys.argv)
        window = MainWindow()
        window.show()
        exit_code = app.exec()
    except Exception as exc:
        import traceback
        print("An exception occurred during startup:")
        traceback.print_exc()
        exit_code = 1
    sys.exit(exit_code)
def closeEvent(self, event):
    if self.process.state() != QProcess.NotRunning:
        self.process.kill()
        self.process.waitForFinished(1000)
    event.accept()

self.statusLabel = QLabel("Module Status: Pending")
self.statusLabel.setStyleSheet("font-size: 16px; color: gray;")
layout.addWidget(self.statusLabel)

# In the MainWindow __init__ method, after you've created self.progressBar, add:
self.moduleStatusLayout = QVBoxLayout()
self.moduleStatusLabel = QLabel("Module Progress:")
self.moduleStatusLayout.addWidget(self.moduleStatusLabel)

# Example modules you want to track; update as needed
self.modules = {
    "Module A": QCheckBox("Module A"),
    "Module B": QCheckBox("Module B"),
    "Module C": QCheckBox("Module C")
}

# Disable user interaction on these checkboxes so they act only as status indicators.
for checkbox in self.modules.values():
    checkbox.setEnabled(False)
    checkbox.setStyleSheet("font-size: 16px;")
    self.moduleStatusLayout.addWidget(checkbox)

layout.addLayout(self.moduleStatusLayout)
