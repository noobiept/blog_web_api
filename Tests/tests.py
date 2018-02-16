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

    def createUser(self, username='test', password='bbbbbb'):
        """
            Create a test user account.
        """
        response = self.makeRequest('/user/create', {
            'username': username,
            'password': password
        })

        return {
            'username': username,
            'password': password,
            **response
        }

    def removeUser(self, info):
        return self.makeRequest('/user/remove', {
            'username': info['username'],
            'password': info['password']
        })

    def addPost(self, info):
        return self.makeRequest(
            '/blog/add', {
                'token': info['token'],
                'title': 'The title.',
                'body': 'The body message.'
            })

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
        response = self.createUser()
        self.assertEqual(response['success'], True)
        self.assertEqual('message' in response, True)
        self.assertEqual('token' in response, True)

        # try to create the same user (shouldn't work since it already exists)
        response = self.createUser()
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)
        self.assertEqual('token' not in response, True)

    def test_user_login(self):
        url = '/user/login'

        self.missingArguments(url, ['username', 'password'])

        # login with an existing account credentials
        info = self.createUser()
        response = self.makeRequest(url, {
            'username': info['username'],
            'password': info['password']
        })
        self.assertEqual(response['success'], True)
        self.assertEqual('token' in response, True)

        # login with correct username but incorrect password
        response = self.makeRequest(url, {
            'username': info['username'],
            'password': 'dsdsdadasdasd'
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)
        self.assertEqual('token' not in response, True)

        # login with incorrect username and password
        response = self.makeRequest(url, {
            'username': 'sdsadsdsdsd',
            'password': 'sdsdsdsd'
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)
        self.assertEqual('token' not in response, True)

    def test_user_remove(self):
        url = '/user/remove'
        info = self.createUser()

        self.missingArguments(url, ['username', 'password'])

        # try to remove with invalid username
        response = self.makeRequest(url, {
            'username': 'sdadasdsad',
            'password': 'ddsdsdsdsda'
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # try to remove with invalid password
        response = self.makeRequest(url, {
            'username': info['username'],
            'password': 'sdsdadsaddsd'
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # remove a user properly
        response = self.makeRequest(url, {
            'username': info['username'],
            'password': info['password']
        })
        self.assertEqual(response['success'], True)

    def test_user_change_password(self):
        url = '/user/change_password'
        info = self.createUser()
        newPass = 'cccccc'

        self.missingArguments(url, ['username', 'password', 'newPassword'])

        # invalid username
        response = self.makeRequest(
            url, {
                'username': 'sdsdsdsd',
                'password': 'sdsddsd',
                'newPassword': 'sdsdsdsd'
            })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # invalid password
        response = self.makeRequest(url, {
            'username': info['username'],
            'password': 'dsdsdsd'
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # not a valid new password (too few characters)
        response = self.makeRequest(
            url, {
                'username': info['username'],
                'password': info['password'],
                'newPassword': '1'
            })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # correct usage
        response = self.makeRequest(
            url, {
                'username': info['username'],
                'password': info['password'],
                'newPassword': newPass
            })
        newToken = response['token']
        self.assertEqual(response['success'], True)
        self.assertEqual('token' in response, True)

        # shouldn't be able to login with previous password
        response = self.makeRequest('/user/login', {
            'username': info['username'],
            'password': info['password']
        })
        self.assertEqual(response['success'], False)

        # but it should work with the new password
        response = self.makeRequest('/user/login', {
            'username': info['username'],
            'password': newPass
        })
        self.assertEqual(response['success'], True)

        # the old token shouldn't work either
        response = self.makeRequest(
            '/blog/add', {
                'token': info['token'],
                'title': 'The title.',
                'body': 'The body message.'
            })
        self.assertEqual(response['success'], False)

        # the new token should
        response = self.makeRequest('/blog/add', {
            'token': newToken,
            'title': 'The title.',
            'body': 'The body message.'
        })
        self.assertEqual(response['success'], True)

    def test_user_invalidate_tokens(self):
        url = '/user/invalidate_tokens'
        info = self.createUser()
        initialToken = info['token']

        self.missingArguments(url, ['username', 'password'])

        # add a blog post
        response = self.makeRequest(
            '/blog/add', {
                'token': initialToken,
                'title': 'The title.',
                'body': 'The body message.'
            })
        self.assertEqual(response['success'], True)

        # invalidate the tokens
        response = self.makeRequest(url, {
            'username': info['username'],
            'password': info['password']
        })
        newToken = response['token']
        self.assertEqual(response['success'], True)
        self.assertEqual('token' in response, True)

        # shouldn't work now with old token
        response = self.makeRequest(
            '/blog/add', {
                'token': initialToken,
                'title': 'The title',
                'body': 'The body message.'
            })
        self.assertEqual(response['success'], False)

        # works with new token
        response = self.makeRequest('/blog/add', {
            'token': newToken,
            'title': 'The title.',
            'body': 'The body message.'
        })
        self.assertEqual(response['success'], True)

    def test_user_getall(self):
        url = '/user/getall'

        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)
        self.assertEqual(len(response['users']), 0)

        # add some users and check the length
        user1 = self.createUser('test1')
        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)
        self.assertEqual(len(response['users']), 1)

        user2 = self.createUser('test2')
        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)
        self.assertEqual(len(response['users']), 2)

        # remove one user
        self.removeUser(user2)
        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)
        self.assertEqual(len(response['users']), 1)

    def test_user_random(self):
        url = '/user/random'

        # no users yet
        response = self.makeRequest(url)
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # one user added, should get that username
        user = self.createUser('test1')
        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)
        self.assertEqual(response['username'], 'test1')
        self.assertEqual(len(response['posts_ids']), 0)

        # add one post and then check if its returned when getting a random user
        post = self.addPost(user)
        response = self.makeRequest(url)
        self.assertEqual(len(response['posts_ids']), 1)
        self.assertEqual(int(response['posts_ids'][0]), post['post_id'])

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