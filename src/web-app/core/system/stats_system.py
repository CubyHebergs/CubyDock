import subprocess
from quantiphy import Quantity
from asgiref.sync import async_to_sync
from ..docker.system import DockerSystem
import shutil
import psutil
import docker
import os

os.environ["DJANGO_ALLOW_ASYNC_UNSAFE"] = "true"

docker = DockerSystem()

def calculate_cpu_percent(d, cpu_count):

    if d["cpu_stats"]["cpu_usage"]["total_usage"] > 0:
        cpu_percent = 0.0
        cpu_delta = float(d["cpu_stats"]["cpu_usage"]["total_usage"]) - \
                    float(d["precpu_stats"]["cpu_usage"]["total_usage"])
        system_delta = float(d["cpu_stats"]["system_cpu_usage"]) - \
                       float(d["precpu_stats"]["system_cpu_usage"])
        if system_delta > 0.0:
            cpu_percent = (cpu_delta / system_delta)*(100*cpu_count)
        return cpu_percent
    else:
        return 0

def stats_cpu(dockersystem=docker):

    list_line = []
    cpu_frequence =  subprocess.Popen(["cat", "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"], stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()[0]
    number_cpu =  dockersystem.info()['NCPU']

    total_frequence_available = int(number_cpu) * (int(cpu_frequence)*1000)

    list_cpu_usage = []
    for container in dockersystem.containers.list():
        list_cpu_usage.append(calculate_cpu_percent(container.stats(stream=False), number_cpu))

    sum_list_cpus = sum(list_cpu_usage)*1000/(int(number_cpu)*1000)
    overload = 0

    if sum_list_cpus > 100.9:
        overload = sum_list_cpus-100

    if psutil.cpu_percent() >= 98 and sum_list_cpus >= 96:
        sum_list_cpus = 100

    return {"overload": overload,
            "all_percent_usage": sum_list_cpus,
            'all_hz_usage': Quantity((total_frequence_available*sum_list_cpus)/100, "hz").render(prec=1),
            "max_cpu_freq": Quantity(int(cpu_frequence)*1000, 'hz').render(prec=1),
            "total_nb_core": int(number_cpu),
            "total_frequency_available": Quantity(total_frequence_available, 'hz').render(prec=1),
    }

def stats_ram(dockersystem=docker):
    docker_info_memory_total = dockersystem.info()['MemTotal']

    all_stats_ram = []
    for container in dockersystem.containers.list():
        if "usage" in container.stats(stream=False)['memory_stats'].keys():
            all_stats_ram.append(container.stats(stream=False)['memory_stats']['usage'])
        else:
            all_stats_ram.append(0)

    return {"total_ram": Quantity(docker_info_memory_total, 'b').render(prec=1),
            "ram_used": Quantity(sum(all_stats_ram), 'b').render(prec=1),
            "all_percent_ram_used": (sum(all_stats_ram)*100)/docker_info_memory_total
    }


def stats_storage(directory="/var/lib/docker/overlay2"):

    total, used, free = shutil.disk_usage(directory)

    total = total // (2**30)
    used = used // (2**30)
    free = free // (2**30)

    percent_used = free * 100 / total

    return { 'total': total ,
             'used': used,
             'free': free,
             'percent_used': round(percent_used, 1),
             'directory': directory
    }
