from django.shortcuts import render
from django.http import HttpResponse


# Create your views here.
class Home():

    @classmethod
    def loginPage(self, request):

        if request.method == "GET":
            return render(
                 request,
                 'base/base_login.html'
            )
