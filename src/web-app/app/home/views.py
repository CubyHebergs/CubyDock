from django.shortcuts import render
from django.http import HttpResponse
from django.contrib.auth import login
from app.tools.dpam.backends import PAMBackend
from core.system.stats_system import *
from django.core.cache import cache
from django.views.decorators.cache import cache_page
import datetime
# Create your views here.
class Home():

    @classmethod
    def loginPage(self, request):

        if request.method == "GET":
            if request.user.is_authenticated:

                return render(
                    request,
                    'app/home/index.html',
                    {"stats": stats_cpu()}
                )
            else:
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
                return HttpResponse("login, success")
            else:
                return render(
                    request,
                    'base/base_login.html',
                    {'loginfail': True}
                )
