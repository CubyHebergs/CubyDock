import docker

class DockerSystem(docker.DockerClient):

    def __init__(self, base_url='unix://var/run/docker.sock'):
        # initialisation class DockerClient
        super().__init__(base_url)
