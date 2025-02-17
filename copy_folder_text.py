#!/usr/bin/env python3
import os
import sys
from PyQt6.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QPushButton,
    QLabel,
    QFileDialog,
    QTextEdit
)
from PyQt6.QtGui import QPalette, QColor
from PyQt6.QtCore import QTimer

class FolderTextCollector(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Folder Text Collector")
        self.resize(800, 600)
        
        layout = QVBoxLayout()

        # Instruction label
        self.status_label = QLabel("Select a folder to extract text from files.")
        layout.addWidget(self.status_label)

        # Button to select folder
        self.select_btn = QPushButton("Select Folder")
        self.select_btn.clicked.connect(self.process_folder)
        layout.addWidget(self.select_btn)

        # Read-only text field to display the combined text
        self.text_edit = QTextEdit()
        self.text_edit.setReadOnly(True)
        layout.addWidget(self.text_edit)
        
        # Button to copy the transformed text to clipboard
        self.copy_btn = QPushButton("Copy Transformed Text to Clipboard")
        self.copy_btn.clicked.connect(self.copy_text)
        layout.addWidget(self.copy_btn)
        
        self.setLayout(layout)

    def process_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Select Folder")
        if not folder:
            self.status_label.setText("No folder selected.")
            return

        combined_text = ""
        # Walk through the folder recursively
        for root, dirs, files in os.walk(folder):
            dirs.sort()
            files.sort()
            for fname in files:
                fpath = os.path.join(root, fname)
                rel_path = os.path.relpath(fpath, folder)
                content = self.read_file_text(fpath)
                # Skip files that cannot be read as text or that appear binary
                if content is None or not self.is_text(content):
                    continue

                # Header for each file with its relative path
                header = f"--- {rel_path} ---\n"
                # Indent each line of the file content for readability
                indented_content = "\n".join("    " + line for line in content.splitlines())
                combined_text += header + indented_content + "\n\n"

        if combined_text.strip():
            self.text_edit.setPlainText(combined_text)
            self.status_label.setText("Text extracted. Click the copy button to transform and copy the text.")
        else:
            self.status_label.setText("No valid text files found in the folder.")
            self.text_edit.clear()

    def read_file_text(self, filepath):
        """Try reading the file as text using UTF-8 then Latin-1 encoding."""
        for encoding in ["utf-8", "latin-1"]:
            try:
                with open(filepath, "r", encoding=encoding) as f:
                    return f.read()
            except Exception:
                continue
        return None

    def is_text(self, s: str) -> bool:
        """
        Return True if at most 30% of characters (ignoring common whitespace)
        are non-printable.
        """
        if not s:
            return False
        total = len(s)
        non_printable = sum(1 for c in s if not c.isprintable() and c not in "\n\r\t")
        return (non_printable / total) <= 0.3

    def transform_text(self, text: str) -> str:
        """
        Transform the text by omitting every 3rd token.
        Prepend a note that every 3rd token has been omitted.
        """
        tokens = text.split()
        # Skip every token where (index+1) % 3 == 0 (i.e. 3rd, 6th, 9th, ...)
        transformed_tokens = [token for i, token in enumerate(tokens) if (i + 1) % 3 != 0]
        transformed_text = " ".join(transformed_tokens)
        note = ("NOTE: Every 3rd token has been omitted and must be correctly guessed.\n\n")
        return note + transformed_text

    def copy_text(self):
        """Copy the transformed text from the text field to the clipboard and change color."""
        original_text = self.text_edit.toPlainText()
        if not original_text.strip():
            self.status_label.setText("Nothing to copy!")
            return

        # Transform the text by omitting every 3rd token
        transformed = self.transform_text(original_text)
        clipboard = QApplication.clipboard()
        clipboard.setText(transformed)
        # Change background color to indicate the copy action
        self.text_edit.setStyleSheet("background-color: lightgreen;")
        self.status_label.setText("Transformed text copied to clipboard!")
        # Revert background color after 2 seconds
        QTimer.singleShot(2000, self.reset_text_edit_color)

    def reset_text_edit_color(self):
        self.text_edit.setStyleSheet("")

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = FolderTextCollector()
    window.show()
    sys.exit(app.exec())
