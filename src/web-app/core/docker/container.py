import subprocess
from quantiphy import Quantity
from django.core.serializers import serialize
from django.http import JsonResponse
from asgiref.sync import async_to_sync
from ..docker.system import DockerSystem
import shutil
import psutil
import os

os.environ["DJANGO_ALLOW_ASYNC_UNSAFE"] = "true"

class Containers():

    @classmethod
    def list_container(self, container_name):

        dict_container = {}
        docker_env = DockerSystem()

        for i, container in enumerate(docker_env.containers.list()):
            dict_container[i] = container.attrs

            return JsonResponse(dict_container, safe=False)
