import subprocess
from quantiphy import Quantity
import psutil


def stats_cpu():

    list_line = []
    cpu_frequence =  subprocess.Popen(["cat", "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"], stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()[0]
    number_cpu = subprocess.Popen(["nproc", "--all"], stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()[0]
    total_frequence_available = int(number_cpu) * (int(cpu_frequence)*1000)
    container_percente_used =  subprocess.Popen(["docker", "stats", "-a", "--no-stream", "--format", '"{{.Container}}: {{.CPUPerc}}"'], stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()[0]

    for container_line in str(container_percente_used).split("\\n"):
       line_parsed = container_line.replace('"', "").replace("b'", "").replace("'", "").replace("%", "").split(": ")
       line_parsed.pop(0)
       if "".join(line_parsed[:1]) != "":
           list_line.append(float("".join(line_parsed[:1])))

    sum_list_cpus = sum(list_line)*1000/(int(number_cpu)*1000)
    overload = 0

    if sum_list_cpus > 100.9:
        overload = sum_list_cpus-100

    if psutil.cpu_percent() >= 98 and sum_list_cpus >= 96:
        sum_list_cpus = 100

    return {"overload": overload,
            "all_percent_usage": sum_list_cpus,
            'all_hz_usage': Quantity((total_frequence_available*sum_list_cpus)/100, "hz").render(),
            "max_cpu_freq": Quantity(int(cpu_frequence)*1000, 'hz').render(),
            "total_nb_core": int(number_cpu),
            "total_frequency_available": Quantity(total_frequence_available, 'hz').render()}
