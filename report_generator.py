
import matplotlib.pyplot as plt
import os
import datetime

def parse_log_dates(log_file):
    """
    Parses the log file for timestamps and builds a simple metric.
    For this example we count how many log entries occur per minute.
    """
    counts = {}
    if not os.path.exists(log_file):
        print(f"Log file not found: {log_file}")
        return counts

    with open(log_file, "r") as f:
        for line in f:
            # Assume log lines are like: [2025-02-17 15:04:12] [Info] message...
            if line.startswith("["):
                try:
                    timestamp_str = line.split("]")[0].lstrip("[")
                    timestamp = datetime.datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S")
                    minute = timestamp.replace(second=0)
                    counts[minute] = counts.get(minute, 0) + 1
                except Exception:
                    continue
    return counts

def plot_log_activity(log_file):
    data = parse_log_dates(log_file)
    if not data:
        print("No data to plot.")
        return

    # sort data by time
    times = sorted(data.keys())
    counts = [data[t] for t in times]

    plt.figure(figsize=(10, 5))
    plt.plot(times, counts, marker='o')
    plt.title("Log Activity Over Time")
    plt.xlabel("Time")
    plt.ylabel("Log Entries")
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    log_path = os.path.join(os.path.abspath("."), "SystemSentinel.log")
    plot_log_activity(log_path)
