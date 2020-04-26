from django.shortcuts import render
from django.http import HttpResponse
from django.contrib.auth import login
from app.tools.dpam.backends import PAMBackend

# Create your views here.
class Home():

    @classmethod

    def loginPage(self, request):

        if request.method == "GET":
            return render(
                request,
                'base/base_login.html'
            )

        if request.method == "POST":

            username = request.POST['username']
            password = request.POST['password']

            user = PAMBackend.authenticate(
                request,
                username=username,
                password=password
            )

            if user is not None:
                login(request, user)
