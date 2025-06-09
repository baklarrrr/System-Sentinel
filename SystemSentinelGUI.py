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
    QCheckBox,
)
from PyQt6.QtGui import QIcon
from PyQt6.QtCore import QProcess
import subprocess

from log_helper import logger  # centralized logging

def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS  # PyInstaller temporary folder
    except AttributeError:
        base_path = os.path.abspath(".")
    full_path = os.path.join(base_path, relative_path)
    if not os.path.exists(full_path):
        logger.error(f"Resource not found: {full_path}")
    return full_path

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

        self.statusLabel = QLabel("Module Status: Pending")
        self.statusLabel.setStyleSheet("font-size: 16px; color: gray;")
        layout.addWidget(self.statusLabel)

        self.moduleStatusLayout = QVBoxLayout()
        self.moduleStatusLabel = QLabel("Module Progress:")
        self.moduleStatusLayout.addWidget(self.moduleStatusLabel)

        self.modules = {
            "Module A": QCheckBox("Module A"),
            "Module B": QCheckBox("Module B"),
            "Module C": QCheckBox("Module C"),
        }

        for checkbox in self.modules.values():
            checkbox.setEnabled(False)
            checkbox.setStyleSheet("font-size: 16px;")
            self.moduleStatusLayout.addWidget(checkbox)

        layout.addLayout(self.moduleStatusLayout)

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
            if sys.platform == "win32":
                os.startfile(log_path)
            else:
                subprocess.Popen(["xdg-open", log_path])
        else:
            QMessageBox.information(self, "Report Not Found", f"No generated log found at:\n{log_path}")

    def closeEvent(self, event):
        if self.process.state() != QProcess.NotRunning:
            self.process.kill()
            self.process.waitForFinished(1000)
        event.accept()

if __name__ == '__main__':
    try:
        app = QApplication(sys.argv)
        window = MainWindow()
        window.show()
        exit_code = app.exec()
    except Exception:
        import traceback
        print("An exception occurred during startup:")
        traceback.print_exc()
        exit_code = 1
    sys.exit(exit_code)
