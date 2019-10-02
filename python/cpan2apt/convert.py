#! /usr/bin/env python3
# coding: UTF-8
import re, sys, os, subprocess

files_dir = "datafiles"
cpan_name_file = "cpan-list.txt"
apt_source_file = "apt-source.txt"

apt_modules = []

def fread(path):
    fp = open(path, "r")
    fbody = fp.read()
    fp.close()
    return fbody

def setAptModules(path):
    body = fread(path)
    lines = re.compile("\n").split(body)
    for line in lines:
        apt_modules.append(line)

def toAptName(name):
    name =  name.lower()
    name = "lib" + re.sub("::", "-", name) + "-perl"
    return name

def searchApt(name):
    if len(name) < 1:
        return None
    name = toAptName(name)
    for apt_module in apt_modules:
        if re.search("^" + name, apt_module):
            return apt_module
    return None

def createAptSource():
    dirname = os.getcwd() + "/" + files_dir
    if not os.path.isdir(dirname):
        print(
            "\033[1;35;40mcreate datadir {dir}\033[0;37;40m".format(dir=dirname)
        )
        os.mkdir(dirname)
    source_filename = dirname + "/" + apt_source_file
    if not os.path.isfile(source_filename):
        print(
            "\033[1;35;40mcreate apt source {file}\033[0;37;40m".format(file=source_filename)
        )
        res = subprocess.run(["/usr/bin/apt", "search", "^lib.+-perl"], stdout=subprocess.PIPE, stderr=None)
        fp = open(source_filename, "w")
        fp.write(res.stdout.decode("utf-8"))
        fp.close()

def getAptModuleList():
    createAptSource()
    fbody = fread(os.getcwd() + "/" + files_dir + "/" + apt_source_file)
    lines = re.compile("\n").split(fbody)
    module_list = []
    for line in lines:
        if not re.search("^lib", line):
            continue
        module_list.append(line)
    return module_list

def getCpanModuleList():
    fbody = fread(os.getcwd() + "/" + files_dir + "/" + cpan_name_file) or sys.exit()
    module_list = re.compile("\n").split(fbody)
    return module_list

def main():
    global apt_modules
    apt_modules = getAptModuleList()
    cpan_modules = getCpanModuleList()

    founds = []
    notFounds = []

    for line in cpan_modules:
        # drop after @
        cpan_name = re.sub(r"@.+", "", line)
        if len(cpan_name) < 1:
            continue
        module_name = searchApt(cpan_name)
        if module_name:
            founds.append(module_name)
        else:
            notFounds.append(cpan_name)

    print("\n\033[1;33;40mFound\033[0;37;40m")
    bySlash = re.compile("/")
    for found in founds:
        print((bySlash.split(found))[0])

    print("\n\033[1;31;40mNOT Found\033[0;37;40m")
    for notFound in notFounds:
        print(notFound)

main()



