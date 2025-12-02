pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property double cpuFreqency: 0

    property var previousCpuStats
    property double cpuTemperature: 0

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    property var lastNetworkCheckTime: 0
    property double networkDownloadSpeed: 0
    property double networkUploadSpeed: 0
    property var previusNetworkStats

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage];
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift();
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage];
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift();
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage];
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift();
        }
    }

    function updateHistories() {
        updateMemoryUsageHistory();
        updateSwapUsageHistory();
        updateCpuUsageHistory();
    }

    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            // Reload files
            fileMeminfo.reload();
            fileStat.reload();
            fileTxStat.reload();
            fileRxStat.reload();

            // Parse Network usage
            const tx = Number(fileTxStat.text().trim());
            const rx = Number(fileRxStat.text().trim());
            const now = Date.now();

            if (previusNetworkStats && lastNetworkCheckTime > 0) {
                const txDiff = tx - previusNetworkStats.tx;
                const rxDiff = rx - previusNetworkStats.rx;

                const timeDiffSec = (now - lastNetworkCheckTime) / 1000;

                if (timeDiffSec > 0) {
                    networkDownloadSpeed = rxDiff / timeDiffSec;
                    networkUploadSpeed = txDiff / timeDiffSec;
                }
            }
            previusNetworkStats = { tx: tx, rx: rx };
            lastNetworkCheckTime = now;

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text();
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1);
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0);
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1);
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0);

            // Parse CPU usage
            const textStat = fileStat.text();
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number);
                const total = stats.reduce((a, b) => a + b, 0);
                const idle = stats[3];

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total;
                    const idleDiff = idle - previousCpuStats.idle;
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;
                }

                previousCpuStats = {
                    total,
                    idle
                };
            }

            // Parse CPU frequency
            const cpuInfo = fileCpuinfo.text();
            const cpuCoreFrequencies = cpuInfo.match(/cpu MHz\s+:\s+(\d+\.\d+)\n/g).map(x => Number(x.match(/\d+\.\d+/)));
            const cpuCoreFreqencyAvg = cpuCoreFrequencies.reduce((a, b) => a + b, 0) / cpuCoreFrequencies.length;
            cpuFreqency = cpuCoreFreqencyAvg / 1000;

            //read cpu temp
            tempProc.running = true

            root.updateHistories();
            interval = Config.options?.resources?.updateInterval ?? 3000;
        }
    }

    FileView {
        id: fileMeminfo
        path: "/proc/meminfo"
    }
    FileView {
        id: fileCpuinfo
        path: "/proc/cpuinfo"
    }
    FileView {
        id: fileStat
        path: "/proc/stat"
    }
    FileView {
        id: fileTxStat
        path: "/sys/class/net/" + Config.options.bar.networkSpeed.interf.trim() + "/statistics/tx_bytes"
    }
    FileView {
        id: fileRxStat
        path: "/sys/class/net/" + Config.options.bar.networkSpeed.interf.trim() + "/statistics/rx_bytes"
    }

    Process { // only run this once
        id: fileCreationtempProc
        running: true
        command: ["bash", "-c", `${Directories.scriptPath}/cpu/coretemp.sh`.replace(/file:\/\//, "")]
    }


    Process {
        id: findCpuMaxFreqProc
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }

    Process { // only run this once
        id: tempProc
        running: true
        command: ["bash", "-c", "cat /tmp/quickshell/coretemp"]
        stdout: StdioCollector {
            onStreamFinished: {
                cpuTemperature = Number(this.text) / 1000;
            }
        }
    }

    Process { // use first ustable interface if interface is not set in config
        id: interfaceProc
        command: ["bash", "-c", "ls /sys/class/net/ | grep -vE '^(lo|br|docker|vir)' | head -n 1"] //exclude some bridge and virtual network interfaces
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                if(Config.options.bar.networkSpeed.interf== ""){
                    Config.options.bar.networkSpeed.interf = this.text
                    print(this.text)
                }
            }
        }
    }
}
