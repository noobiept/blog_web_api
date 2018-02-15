import unittest
import requests
import json
import os.path
from urllib.parse import urljoin
import itertools
import subprocess

URL = 'http://localhost:8000/'


class TestBlog(unittest.TestCase):
    def setUp(self):
        """
            Clear the database before every test.
        """
        subprocess.call(["redis-cli", "flushall"])

    def createUser(self):
        """
            Create a test user account.
        """
        username = 'testUsername'
        password = 'bbbbbb'

        response = self.makeRequest('/user/create', {
            'username': username,
            'password': password
        })

        return {
            'username': username,
            'password': password,
            'response': response
        }

    def makeRequest(self, path, data=None):
        """
            Make a GET request if 'data' is not passed.
            Otherwise do a POST request with the given 'data' dictionary.
        """
        completeUrl = urljoin(URL, path)

        if data is None:
            r = requests.get(completeUrl)

        else:
            r = requests.post(completeUrl, data=data)

        return json.loads(r.text)

    def missingArguments(self, url, arguments):
        """
            Test all combinations of missing arguments.
            The request shouldn't be successfull (since its missing at least 1 argument).
        """
        for length in range(0, len(arguments)):
            # get all the combinations of arguments possible (of different lengths)
            combinations = itertools.combinations(arguments, length)

            for combination in combinations:
                data = {}

                # construct a data argument to pass along (doesn't matter the actual data, just that we're passing along that argument)
                for argument in combination:
                    data[argument] = '1'

                # make a request with an incomplete set of arguments, it shouldn't work
                response = self.makeRequest(url, data)
                self.assertEqual(response['success'], False)

    def test_user_create(self):
        url = '/user/create'

        self.missingArguments(url, ['username', 'password'])

        # create a new user
        info = self.createUser()
        response = info['response']

        self.assertEqual(response['success'], True)
        self.assertEqual('message' in response, True)
        self.assertEqual('token' in response, True)

        # try to create the same user (shouldn't work since it already exists)
        info2 = self.createUser()
        response2 = info2['response']

        self.assertEqual(response2['success'], False)
        self.assertEqual('message' in response2, True)

    def test_user_login(self):
        url = '/user/login'

        self.missingArguments(url, ['username', 'password'])

    def test_user_remove(self):
        url = '/user/remove'

        self.missingArguments(url, ['username', 'password'])

    def test_user_change_password(self):
        url = '/user/change_password'

        self.missingArguments(url, ['username', 'password', 'newPassword'])

    def test_user_invalidate_tokens(self):
        url = '/user/invalidate_tokens'

        self.missingArguments(url, ['username', 'password'])

    def test_user_getall(self):
        url = '/user/getall'

        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)

    def test_user_random(self):
        url = '/user/random'

    def test_blog_add(self):
        url = '/blog/add'

        self.missingArguments(url, ['token', 'title', 'body'])

    def test_blog_get(self):
        url = '/blog/get/:blogId'

    def test_blog_remove(self):
        url = 'blog/remove'

        self.missingArguments(url, ['token', 'blogId'])

    def test_blog_update(self):
        url = '/blog/update'

        self.missingArguments(url, ['token', 'title', 'body', 'blogId'])

    def test_blog_username_getall(self):
        url = '/blog/:username/getall'

    def test_blog_random(self):
        url = '/blog/random'

    def test_blog_getall(self):
        url = '/blog/getall'


if __name__ == '__main__':
    unittest.main()