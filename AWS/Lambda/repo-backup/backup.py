#!/usr/bin/python
import json
import logging
import os
import os.path
import string
import sys
import tarfile
import zipfile
from datetime import datetime

import base64
import boto3
import botocore
import requests
from botocore.errorfactory import ClientError

logging.getLogger("requests").setLevel(logging.WARNING)

AccessKey = os.environ['AWS_ACCESS_KEY']
AccessSecret = os.environ['AWS_ACCESS_SECRET']
AccessRoleArn = os.environ['ACCESS_ROLE_ARN']

token = os.environ['VSTS_TOKEN']
GITtoken = os.environ['GIT_TOKEN']

GitHubOrg = os.environ['GITHUB_ORG']
AzureDevopsOrg = os.environ['AZURE_DEVOPS_ORG']

s3BucketName = os.environ['S3_BUCKET_NAME']
s3RegionName = os.environ['REGION'] # "eu-west-1" # Replace with your Region name
s3SessionName = "My-Session-name" #replace with your session name


if token == "" or token == None:
    logging.error("The VSTS Token was empty")
    sys.exit(1)
if GITtoken == "" or GITtoken == None:
    logging.error("The GIT token was empty")
    sys.exit(1)

class PROJECTINIT():
    def __init__(self,devops_base_uri="https://dev.azure.com/",devops_account=f'{AzureDevopsOrg}', devops_api_version = "7.1", git_base_uri="https://api.github.com",gitorg=f'{GitHubOrg}') -> None:
        self.devops_base_uri = devops_base_uri
        self.devops_account = devops_account
        self.devops_api_version = devops_api_version
        self.git_base_uri = git_base_uri
        self.gitorg = gitorg
    @staticmethod
    def initialize_logger(output_dir):
        output_dir = os.path.normpath(output_dir)
        logger = logging.getLogger()
        logger.setLevel(logging.DEBUG)

        # create console handler and set level to info
        handler = logging.StreamHandler()
        handler.setLevel(logging.INFO)
        formatter = logging.Formatter("%(asctime)s %(levelname)s - %(message)s", datefmt='%Y-%m-%d %H:%M:%S')
        handler.setFormatter(formatter)
        logger.addHandler(handler)

        # create error file handler and set level to error
        handler = logging.FileHandler(os.path.join(output_dir, "error.log"),"w", encoding=None, delay="true")
        handler.setLevel(logging.ERROR)
        formatter = logging.Formatter("%(asctime)s %(levelname)s - %(message)s", datefmt='%Y-%m-%d %H:%M:%S')
        handler.setFormatter(formatter)
        logger.addHandler(handler)

        # create error file handler and set level to error
        handler = logging.FileHandler(os.path.join(output_dir, "logging.log"),"w", encoding=None, delay="true")
        handler.setLevel(logging.INFO)
        formatter = logging.Formatter("%(asctime)s %(levelname)s - %(message)s", datefmt='%Y-%m-%d %H:%M:%S')
        handler.setFormatter(formatter)
        logger.addHandler(handler)

        # create debug file handler and set level to debug
        handler = logging.FileHandler(os.path.join(output_dir, "debug.log"),"w")
        handler.setLevel(logging.DEBUG)
        formatter = logging.Formatter("%(asctime)s %(levelname)s - %(message)s", datefmt='%Y-%m-%d %H:%M:%S')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    def projects_uri(self):
        projecturireturn = f"{self.devops_base_uri}{self.devops_account}/_apis/projects?api-version={self.devops_api_version}"
        logging.debug("Using API Uri: %s", projecturireturn)
        return projecturireturn
    @staticmethod
    def load_data_from_file(Path, filename):
        try:
            filepath = os.path.normpath(Path + "/" + filename)
            json_data=open(filepath, encoding="utf-8").read()
            data = json.loads(json_data)
            logging.debug("Read file succesful (%s)", targetpath + "/" + filename)
            return data
        except IOError as e:
            logging.error("Cannot read from file (%s) %s", Path + "/" + filename, e.strerror)
            return None
    @staticmethod
    def make_safe_file_name(input_file_name):
        safechars = string.ascii_letters + string.digits + "~ -_."
        try:
            return "".join(list(filter(lambda c: c in safechars, input_file_name)))
        except:
            return ""
    @staticmethod
    def tardir(path,tar_name):
        try:
            with tarfile.open(tar_name, "w:gz") as tar_handle:
                for root, dirs, files in os.walk(path):
                    for file in files:
                        tar_handle.add(os.path.join(root, file))
        except tarfile.TarError as err:
            logging.error("ERROR Compressing %s, error : %s",path,err)
    @staticmethod
    def check_result(result):
        if result == 200:
            logging.debug("API Call completed successfully")
        else:
            logging.error(result)
    @staticmethod
    def token_encode_decode():
        combined = f"Basic:{token}"
        encoded = base64.b64encode(combined.encode()).decode()
        auth_header = f"Basic {encoded}"
        return auth_header

class S3CLIENTCONNECTION():
    @staticmethod
    def _boto3_client_init(access_key=f"{AccessKey}", secret_key=f"{AccessSecret}", role_arn=f"{AccessRoleArn}", region=f'{s3RegionName}', session_name=f'{s3SessionName}'):
        sts_client = boto3.client(
            'sts',
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region,
        )
        assumed_role_object = sts_client.assume_role(
            RoleArn=role_arn,
            RoleSessionName=session_name
        )
        credentials = assumed_role_object['Credentials']
        session = boto3.Session(
            aws_access_key_id=credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken'],
        )
        s3 = session.client('s3')
        return s3

class S3UPLOAD(S3CLIENTCONNECTION):
    def __init__ (self, targetpath, archive_folder, bucket_name=f"{s3BucketName}") -> None:
        self._s3_client = self._boto3_client_init()
        self._archive_folder = archive_folder
        self._archive_name = self._archive_folder+"-RepoBackup.zip"
        self._bucket_name = bucket_name
        self._zip_size = os.path.getsize(targetpath + "/" + archive_folder+"-Repobackup.zip")

    def upload_to_s3_method(self, targetpath,source_file,target_prefix,bucket):
        logging.info ("Uploading Archive (%s) to S3 (%s)",source_file,self._bucket_name+"/"+target_prefix)
        try:
            result = self._s3_client.upload_file(targetpath + "/" + source_file, bucket, target_prefix + "/" + source_file)
            logging.debug ("Upload %s Success", source_file)
        except ClientError as e:
            logging.error ("Upload %s Fail, error: %s", source_file, e)

    def upload_to_s3_action(self):
        ## Upload to S3
        logging.info("")
        if dry_run:
            logging.info('dry_run, not uploading to S3')
        else:
            self.upload_to_s3_method(targetpath,self._archive_name,self._archive_folder,self._bucket_name)
            self.upload_to_s3_method(targetpath,"logging.log",self._archive_folder,self._bucket_name)
            self.upload_to_s3_method(targetpath,"debug.log",self._archive_folder,self._bucket_name)
            ## Verify Upload
            logging.info("")
            try:
                res = self._s3_client.head_object(Bucket=self._bucket_name, Key=self._archive_folder + "/" + self._archive_name)
                #logging.info (json.dumps(res,indent=4, sort_keys=True, default=str))
                if res['ResponseMetadata']['HTTPStatusCode'] == 200:
                    s3_size = res['ResponseMetadata']['HTTPHeaders']['content-length']
                    if int(s3_size) == int(self._zip_size):
                        logging.info("File Upload to S3 successfull, filesize on S3 = %s",s3_size)
                    else:
                        logging.error("File Upload to S3 unsuccessfull, filesize on S3 = %s filesize on disk %s",s3_size,self._zip_size)
            except ClientError as e:
                # Not found
                logging.error("File Upload to S3 unsuccessfull, cannot retrieve file information")
                pass

            ## Overall result
            logging.info("")
            Errors = os.path.exists(targetpath + '/error.log')
            if Errors:
                logging.error("Backup unsuccessfull, check error.log")
                self.UploadToS3Method(targetpath,"error.log",self._ArchiveFolder,self._BucketName)
                sys.exit(1)
            else:
                logging.info("Backup successfull, no error occurred.")
class DOWNLOADPROJECTS(PROJECTINIT):
    def download_devops_json(self,uri,token):
        try:
            logging.debug("Using API Uri: %s", uri)
            response = requests.get(uri, headers={"ContentType": "application/json", 'Authorization': self.token_encode_decode()}, verify = True)
            return response
        except requests.ConnectionError as e:
            return e.args

    def download_github_json(self,uri,token):
        try:
            logging.debug("Using API Uri: %s", uri)
            response = requests.get(uri, headers={"ContentType": "application/json"}, verify = True, auth = (token,''))
            return response
        except requests.ConnectionError as e:
            return e.args

    def write_to_file(self,targetpath,filename,content):
        try:
            if not os.path.exists(targetpath):
                os.makedirs(targetpath)

            newfile = open(targetpath + "/" + filename, "w", encoding="utf-8")
            if isinstance(content, (bytes, bytearray)):
                newfile.write(content.decode('utf-8'))
            else:
                newfile.write(content)
            newfile.close
            logging.debug("Write file succesful (%s)", targetpath + "/" + filename)
            return True
        except IOError as e:
            logging.error("Cannot write to file (%s) %s", targetpath + "/" + filename, e.strerror)
            return False

    def download_repo(self,type,account,team,repo,branch,token,targetpath):
        if type == 'DevOps':
            zip_uri = ("https://dev.azure.com/{}/{}/_apis/git/repositories/{}/Items?path=%2F&versionDescriptor%5BversionOptions%5D=0&versionDescriptor%5BversionType%5D=0&versionDescriptor%5Bversion%5D={}&resolveLfs=true&%24format=zip&api-version={}").format(account,team,repo,branch,self.devops_api_version)
        elif type == 'GitHub':
            zip_uri = ("https://github.com/{}/{}/archive/{}.zip").format(account,repo,branch)
        else:
            logging.debug("Git Type not found")
            return

        logging.debug("Using API Uri: %s", zip_uri)
        if type == 'DevOps':
            try:
                authtoken = self.token_encode_decode()
                logging.info("Downloading repository %s",repo)
                response = requests.get(zip_uri, headers={"ContentType": "application/json",'Authorization': f"{authtoken}"})
                if not os.path.exists(targetpath + "/" + team + "/Repos"):
                    os.makedirs(targetpath + "/" + team + "/Repos")
                if response.status_code == 200:
                    handle = open(targetpath + "/" + team + "/Repos" + "/" + repo + ".zip", "wb")
                    for chunk in response.iter_content(chunk_size=512):
                        if chunk:  # filter out keep-alive new chunks
                            handle.write(chunk)
                    handle.close()
                    zip_size = os.path.getsize(targetpath + "/" + team + "/Repos" + "/" + repo + ".zip")
                    if zip_size > 1014: #Check if file is larger than 1024 Bytes
                        logging.info("Repository downloaded to %s, Size %s", targetpath + "/" + team + "/Repos" + "/" + repo + ".zip", zip_size)
                        return True
                    else:
                        logging.info("Repository download unsuccessful to %s, Size %s", targetpath + "/" + team + "/Repos" + "/" + repo + ".zip", zip_size)
                else:
                        logging.warning("Cannot download repo, %s", response)
            except requests.ConnectionError as e:
                logging.error("Cannot download repository to file (%s) %s", targetpath + "/" + team + "/Repos" + "/" + repo + ".zip", e.strerror)
                logging.error(response.text)
                return False
        else:
            try:
                logging.info("Downloading repository %s",repo)
                response = requests.get(zip_uri, headers={"ContentType": "application/json", "Authorization": f"Bearer {GITtoken}"}, stream=True)
                if not os.path.exists(targetpath + "/" + team + "/Repos"):
                    os.makedirs(targetpath + "/" + team + "/Repos")

                if response.status_code == 200:
                    handle = open(targetpath + "/" + team + "/Repos" + "/" + repo + ".zip", "wb")
                    for chunk in response.iter_content(chunk_size=512):
                        if chunk:  # filter out keep-alive new chunks
                            handle.write(chunk)
                    handle.close()
                    zip_size = os.path.getsize(targetpath + "/" + team + "/Repos" + "/" + repo + ".zip")
                    if zip_size > 1014: #Check if file is larger than 1024 Bytes
                        logging.info("Repository downloaded to %s, Size %s", targetpath + "/" + team + "/Repos" + "/" + repo + ".zip", zip_size)
                        return True
                    else:
                        logging.info("Repository download unsuccessful to %s, Size %s", targetpath + "/" + team + "/Repos" + "/" + repo + ".zip", zip_size)
                else:
                        logging.warning("Cannot download repo, %s", response)
            except requests.ConnectionError as e:
                logging.error("Cannot download repository to file (%s) %s", targetpath + "/" + team + "/Repos" + "/" + repo + ".zip", e.strerror)
                return False

    def get_release_definitions(self, releasedata,account,project_name,token,targetpath):
        def_ids = []
        if 'value' in releasedata:
            task_ids = []
            for Id in releasedata['value']:

                if Id['id'] not in def_ids:
                    def_ids.append({'DefinitionId':Id['id'],'DefinitionName':Id['name']}) #(str(Id['id'])) #

            for id in def_ids:
                #print(id['DefinitionId'])
                release_def_uri = ("https://vsrm.dev.azure.com/{}/{}/_apis/release/definitions/{}?api-version={}").format(account,project_name,str(id['DefinitionId']),self.devops_api_version)
                logging.debug("Using API Uri: %s", release_def_uri)
                result = self.download_github_json(release_def_uri,token)
                project_init.check_result(result.status_code)
                if result.status_code == 200:
                    path = "%s/%s/ReleaseDefinitions" % (targetpath,project_name)
                    filename = '%s.json' % (project_init.make_safe_file_name(str(id['DefinitionName'])) )
                    res = self.write_to_file(path,filename,result.content)
                releasedefdata = self.load_data_from_file(targetpath+"/"+project_name+"/ReleaseDefinitions",project_init.make_safe_file_name(str(id['DefinitionName']))+'.json')

                #Extract taskgroup ids from DeployPhases
                temp_task = []
                if releasedefdata != None:
                    if 'environments' in releasedefdata:
                        for Environment in releasedefdata['environments']:
                            if 'deployPhases' in Environment:
                                for Phase in Environment['deployPhases']:
                                    if 'workflowTasks' in Phase:
                                        for workflowTask in Phase['workflowTasks']:
                                            if 'taskId' in workflowTask:
                                                if workflowTask['taskId'] not in temp_task:
                                                    temp_task.append(workflowTask['taskId'])
                    task_ids.append({'ProjectName':project_name,'DefinitionName':str(id['DefinitionName']),'Tasks':temp_task})
                else:
                    logging.info("No release definition data found in file %s", targetpath+"/"+project_name + "/ReleaseDefinitions/"+str(id['DefinitionName'])+'.json' )
                    return False

            self.write_to_file(targetpath+"/"+project_name + "/",project_name + "_tasks.json",json.dumps(task_ids))
            return task_ids
class PROCESSPROJECTS(DOWNLOADPROJECTS):
    #Load Project and loop through
    def loop_through_repos(self, data):
        #Get Repos, Endpoints, Releases, ReleaseDefinitions, TaskGroups for each Project
        if data != None:
            if 'value' in data:
                for project in data['value']:
                    project_name = str(project['name'])
                    
                    logging.info("")
                    logging.info ("Gather Repos data for : %s", project_name)
                    repo_uri = f"{self.devops_base_uri}{self.devops_account}/{project_name}/_apis/git/repositories?includeLinks=true&includeAllUrls=true&includeHidden=true&api-version={self.devops_api_version}"
                    result = self.download_devops_json(repo_uri,token)
                    project_init.check_result(result.status_code)
                    if result.status_code == 200:
                        res = self.write_to_file(targetpath+"/"+project_name,"repos.json",result.content)
                    #Download Repos
                    repos = self.load_data_from_file(targetpath+"/"+project_name , "repos.json")
                    if 'value' in repos:
                        for repo in repos['value']:
                            if 'defaultBranch' in repo:
                                branch = repo['defaultBranch'][repo['defaultBranch'].rfind("/")+1:len(repo['defaultBranch'])]
                                if dry_run:
                                    logging.info('dry_run, not downloading %s', (repo['name'])) 
                                else:
                                    self.download_repo("DevOps",self.devops_account,project_name,repo['name'],branch,token,targetpath)
                            #sys.exit()
                    print(project)

                    #Releases
                    logging.info ("Gather Release data for : %s", project_name)
                    release_uri = ("https://vsrm.dev.azure.com/{}/{}/_apis/release/definitions?api-version={}").format(self.devops_account,project_name,self.devops_api_version)
                    #logging.info (ReleaseUri)
                    result = self.download_github_json(release_uri,token)
                    project_init.check_result(result.status_code)
                    if result.status_code == 200:
                        res = self.write_to_file(targetpath+"/"+project_name,"releases.json",result.content)

                    #ReleaseDefinitions
                    logging.info ("Gather Release Definition data for : %s", project_name)
                    releasedata = self.load_data_from_file(targetpath+"/"+project_name,"releases.json")

                    #Retreive all Definition Id's
                    if releasedata != None:
                        task_ids = self.get_release_definitions(releasedata,self.devops_account,project_name,token,targetpath)
                    else:
                        logging.info("No release data found in file %s", targetpath+"/"+project_name + "/releases.json" )

                    
        else:
            logging.info("No projects in file %s", targetpath+ "/projects.json" )
class GITHUBCOLLECT(PROCESSPROJECTS):
    def gather_github_data(self):
        ## GitHub
        logging.info("")
        logging.info ("Gather Github data")
        logging.info ("Gather Github user data")
        git_users_uri = ("{}/orgs/{}/members").format(self.git_base_uri,self.gitorg)
        result = self.download_github_json(git_users_uri,GITtoken)
        project_init.check_result(result.status_code)
        if result.status_code == 200:
            res = self.write_to_file(targetpath+"/GitHub","users.json",result.content)
        else:
            logging.info("No Github users found")
    def gather_github_user(self):
        ## GitHub Users
        users = self.load_data_from_file(targetpath+"/GitHub","users.json")
        if len(users) >= 1:
            logging.info("Found %s users in file %s, retrieving individual user information",len(users),targetpath+"/GitHub/users.json")
            for user in users:
                git_user_uri = ("{}/users/{}").format(self.git_base_uri,user['login'])
                result = self.download_github_json(git_user_uri,GITtoken)
                if result.status_code == 200:
                    res = self.write_to_file(targetpath+"/GitHub/Users",user['login']+".json",result.content)
                else:
                    logging.info("Could not retrieve data for %s",user['login'])
        else:
            logging.info("No users found in file %s", targetpath+"/GitHub/users.json" )
    def gather_github_repos(self):
        ## GitHub Repos
        logging.info ("Gather Github Repo data")
        # old: GitRepoUri = ("{}/user/repos").format(git_base_uri)
        git_repo_uri = ("{}/orgs/{}/repos?type=all").format(self.git_base_uri,self.gitorg)
        result = self.download_github_json(git_repo_uri,GITtoken)
        project_init.check_result(result.status_code)
        if result.status_code == 200:
            res = self.write_to_file(targetpath+"/GitHub","Repos.json",result.content)
        else:
            logging.info("No Github Repos found")

        ## Download GitHub Repos
        repos = self.load_data_from_file(targetpath+"/GitHub","Repos.json")
        if len(repos) >= 1:
            logging.info("Found %s Repos in file %s, retrieving individual Repo information",len(repos),targetpath+"/GitHub/Repos.json")
            for repo in repos:
                git_repo_url = ("https://github.com/{}/{}/archive/main.zip").format(self.gitorg,repo['name'])
                if dry_run:
                    logging.info('dry_run, not downloading') 
                else:
                    self.download_repo("GitHub",self.gitorg,"GitHub",repo['name'],"main",GITtoken,targetpath)
class ARCHIVAL(PROCESSPROJECTS):
    def archive_method(self, archive_folder):
        _archive_name = f"{archive_folder}-RepoBackup.zip"
        ## Compress all files
        logging.info("")
        logging.info ("Creating Archive from all files")
        if dry_run:
            logging.info('dry_run, not compressing')
        else:
            print(f"The name will be {targetpath}/{_archive_name}")
            self.tardir(targetpath, targetpath + "/" + _archive_name)
            #CompressFolder(targetpath, targetpath, _archive_name)
            _zip_size = os.path.getsize(targetpath + "/" + _archive_name)
            if _zip_size > 1014: #Check if file is larger than 1024 Bytes
                logging.info("Compress successfull, Archive Size %s",_zip_size)
            else:
                logging.error("Compress unsuccessfull, Archive Size %s",_zip_size)
#Setting parameters:
targetpath = "Backup"
if not os.path.exists(targetpath):
    os.makedirs(targetpath)

#Dry_run = None
dry_run = True if '--dry-run' in sys.argv else False
single_project = True if '--single-project' in sys.argv else False

#Get Projects
project_init = PROJECTINIT()
project_init.initialize_logger(targetpath)
projects_uri = project_init.projects_uri()
project_download = DOWNLOADPROJECTS()
process_projects = PROCESSPROJECTS()

result = project_download.download_github_json(projects_uri,token)
if result.status_code == 200:
    res = project_download.write_to_file(targetpath,"projects.json",result.content)
    projectdata = project_download.load_data_from_file(targetpath , "projects.json")
    process_projects.loop_through_repos(projectdata)
githubcollect = GITHUBCOLLECT()
try:
    githubcollect.gather_github_data()
    githubcollect.gather_github_user()
    githubcollect.gather_github_repos()
    # print(os.listdir(targetpath+"/GitHub/Repos"))
    # print(os.listdir(targetpath+"/GitHub/Users"))
except Exception as esx:
    raise Exception("Error in Githubcollect.") from esx
if targetpath is not None:
    print(os.listdir(targetpath))
    # Set current runtime as archive time
    archive_time = datetime.now().strftime("%Y%m%d_%H%M%S")
    print(f"Setting current archive time to {archive_time}")
    print("Now trying to archive stuff")
    ARCHIVAL().archive_method(archive_time)
    print("Succesfully archived stuff. Continuing the S3")
    s3_upload_class = S3UPLOAD(targetpath,archive_time)
    s3_upload_class.upload_to_s3_action()
    print("Writing content to S3 succeeded.")
else:
    raise Exception(f"The targetpath is empty/filled with: {targetpath}")
