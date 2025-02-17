import sys, os
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLabel, QPushButton,
    QMessageBox, QTextEdit, QProgressBar
)
from PyQt6.QtGui import QIcon, QPalette, QColor
from PyQt6.QtCore import QProcess

def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except AttributeError:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

class MainWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("System Sentinel")
        self.setWindowIcon(QIcon(resource_path("SystemSentinel.ico")))
        self.resize(600, 400)
        layout = QVBoxLayout()

        self.label = QLabel("System Sentinel: Cleaning Your System...")
        self.label.setStyleSheet("font-size: 18px;")
        layout.addWidget(self.label)

        self.logText = QTextEdit()
        self.logText.setReadOnly(True)
        layout.addWidget(self.logText)

        self.progressBar = QProgressBar()
        self.progressBar.setRange(0, 0)  # Indeterminate progress
        self.progressBar.setVisible(False)
        layout.addWidget(self.progressBar)

        self.runButton = QPushButton("Run System Sentinel")
        self.runButton.setStyleSheet("padding: 10px; font-size: 16px;")
        self.runButton.clicked.connect(self.run_sentinel)
        layout.addWidget(self.runButton)

        self.setLayout(layout)

        # Set up QProcess for running the PowerShell script
        self.process = QProcess(self)
        self.process.readyReadStandardOutput.connect(self.handle_stdout)
        self.process.readyReadStandardError.connect(self.handle_stderr)
        self.process.finished.connect(self.process_finished)

    def run_sentinel(self):
        self.logText.append("Starting System Sentinel...")
        self.progressBar.setVisible(True)
        self.runButton.setEnabled(False)
        script_path = resource_path("SystemSentinel.ps1")
        if not os.path.exists(script_path):
            QMessageBox.critical(self, "Error", f"SystemSentinel.ps1 not found at:\n{script_path}")
            self.runButton.setEnabled(True)
            self.progressBar.setVisible(False)
            return

        # Start the PowerShell process
        self.process.start("powershell.exe", ["-ExecutionPolicy", "Bypass", "-File", script_path])

    def handle_stdout(self):
        data = self.process.readAllStandardOutput().data().decode("utf-8")
        self.logText.append(data)

    def handle_stderr(self):
        data = self.process.readAllStandardError().data().decode("utf-8")
        self.logText.append("<font color='red'>" + data + "</font>")

    def process_finished(self):
        self.logText.append("System Sentinel execution finished.")
        self.progressBar.setVisible(False)
        self.runButton.setEnabled(True)
        QMessageBox.information(self, "Finished", "System Sentinel has finished cleaning your system.\nCheck the logs for details.")

def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    palette = QPalette()
    palette.setColor(QPalette.ColorRole.Window, QColor(53,53,53))
    palette.setColor(QPalette.ColorRole.WindowText, QColor(255,255,255))
    palette.setColor(QPalette.ColorRole.Base, QColor(25,25,25))
    palette.setColor(QPalette.ColorRole.AlternateBase, QColor(53,53,53))
    palette.setColor(QPalette.ColorRole.ToolTipBase, QColor(255,255,255))
    palette.setColor(QPalette.ColorRole.ToolTipText, QColor(255,255,255))
    palette.setColor(QPalette.ColorRole.Text, QColor(255,255,255))
    palette.setColor(QPalette.ColorRole.Button, QColor(53,53,53))
    palette.setColor(QPalette.ColorRole.ButtonText, QColor(255,255,255))
    palette.setColor(QPalette.ColorRole.BrightText, QColor(255,0,0))
    palette.setColor(QPalette.ColorRole.Link, QColor(42,130,218))
    palette.setColor(QPalette.ColorRole.Highlight, QColor(42,130,218))
    palette.setColor(QPalette.ColorRole.HighlightedText, QColor(0,0,0))
    app.setPalette(palette)

    window = MainWindow()
    window.show()
    sys.exit(app.exec())

if __name__ == '__main__':
    main()
