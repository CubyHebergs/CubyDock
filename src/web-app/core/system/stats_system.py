import subprocess
from quantiphy import Quantity

class System_stats():

    def __init__(self):
        pass

    def stats_cpu(self):
        cpu_container = {}
        list_line = []
        cpu_frequence =  subprocess.Popen(["cat", "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        number_cpu = subprocess.Popen(["nproc", "--all"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        total_frequence_available = int(number_cpu.communicate()[0]) * (int(cpu_frequence.communicate()[0])*1000)
        container_percente_used =  subprocess.Popen(["docker", "stats", "-a", "--no-stream", "--format", '"{{.Container}}: {{.CPUPerc}}"'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        for container_line in str(container_percente_used.communicate()[0]).split("\\n"):
           line_parsed = container_line.replace('"', "").replace("b'", "").replace("'", "").replace("%", "").split(": ")
           line_parsed.pop(0)
           if "".join(line_parsed[:1]) != "":
               list_line.append(float("".join(line_parsed[:1])))

        return {"all_percent_usage": sum(list_line),
                "max_cpu_freq": Quantity(int(cpu_frequence.communicate()[0])*1000, 'hz').render(),
                "total_nb_core": int(number_cpu.communicate()[0]),
                "total_frequency_available": Quantity(total_frequence_available, 'hz').render()}
