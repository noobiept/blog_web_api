import unittest
import requests
import json
import os.path
from urllib.parse import urljoin
import itertools
import subprocess
import os

URL = 'http://localhost:8000/'
USERNAME_LOWER_LIMIT = 3
USERNAME_UPPER_LIMIT = 20
PASSWORD_LOWER_LIMIT = 6
PASSWORD_UPPER_LIMIT = 20
TITLE_LOWER_LIMIT = 5
TITLE_UPPER_LIMIT = 100
BODY_LOWER_LIMIT = 10
BODY_UPPER_LIMIT = 10000
DEVNULL = open(os.devnull, 'w')


class TestBlog(unittest.TestCase):
    def setUp(self):
        """
            Clear the database before every test.
        """
        subprocess.call(["redis-cli", "flushall"], stdout=DEVNULL)

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

    def addPost(self, userInfo):
        title = 'The title.'
        body = 'The body message.'
        response = self.makeRequest(
            '/blog/add', {
                'token': userInfo['token'],
                'title': title,
                'body': body
            })

        return {
            'title': title,
            'body': body,
            **response
        }

    def titleBodyTest(self, url, data):
        """
            Test the lower and upper limit of the 'title' and 'body' values.
        """
        self.limitsTest(url, 'title', TITLE_LOWER_LIMIT, TITLE_UPPER_LIMIT, {
            **data,
            'body': 'The body message.'
        })
        self.limitsTest(url, 'body', BODY_LOWER_LIMIT, BODY_UPPER_LIMIT, {
            **data,
            'title': 'The title.'
        })

    def limitsTest(self, url, propName, lower, upper, data):
        # test the lower limit
        response = self.makeRequest(url, {
            **data,
            propName: '1' * (lower - 1)
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # test the upper limit
        response = self.makeRequest(url, {
            **data,
            propName: '1' * (upper + 1)
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

    def postTest(self, postId, author, title, body):
        """
            Check if a post of the given ID has the correct title/body/etc.
        """
        response = self.makeRequest('/blog/get/{0}'.format(postId))

        self.assertEqual(response['success'], True)
        self.assertEqual(response['post']['body'], body)
        self.assertEqual(response['post']['author'], author)
        self.assertEqual(response['post']['title'], title)
        self.assertEqual('last_updated' in response['post'], True)

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

        # test lower and upper limits of 'username' and 'password'
        self.limitsTest(url, 'username', USERNAME_LOWER_LIMIT, USERNAME_UPPER_LIMIT, {
            'password': 'bbbbbb'
        })
        self.limitsTest(url, 'password', PASSWORD_LOWER_LIMIT, PASSWORD_UPPER_LIMIT, {
            'username': 'aaa'
        })

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
        post = self.addPost(info)
        username = info['username']

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
            'username': username,
            'password': 'sdsdadsaddsd'
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # remove a user properly and check if the post was removed as well
        response = self.makeRequest(
            '/blog/{0}/getall'.format(username))
        self.assertEqual(len(response['posts_ids']), 1)

        response = self.makeRequest(url, {
            'username': username,
            'password': info['password']
        })
        self.assertEqual(response['success'], True)

        response = self.makeRequest(
            '/blog/{0}/getall'.format(username))
        self.assertEqual(response['success'], False)

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

        # not a valid new password (test the lower and upper limits)
        self.limitsTest(url, 'newPassword', PASSWORD_LOWER_LIMIT, PASSWORD_UPPER_LIMIT, {
            'username': info['username'],
            'password': info['password']
        })

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
        user = self.createUser()
        title = 'The title.'
        body = 'The body message.'

        self.missingArguments(url, ['token', 'title', 'body'])

        # shouldn't work with an incorrect token
        response = self.makeRequest(url, {
            'token': 'aaaa',
            'title': title,
            'body': body
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # there's a lower and upper limit to both the 'title' and 'body'
        self.titleBodyTest(url, {
            'token': user['token']
        })

        # correct usage
        response = self.makeRequest(url, {
            'token': user['token'],
            'title': title,
            'body': body
        })
        self.assertEqual(response['success'], True)
        self.assertEqual('post_id' in response, True)

        # try to get it with the given ID, and compare the values
        self.postTest(response['post_id'], user['username'], title, body)

    def test_blog_get(self):
        url = '/blog/get/{0}'

        # test with a string argument
        response = self.makeRequest(url.format('a'))
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # test with a non-existing ID
        response = self.makeRequest(url.format(1))
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # correct usage
        user = self.createUser()
        post = self.addPost(user)
        self.postTest(post['post_id'], user['username'],
                      post['title'], post['body'])

    def test_blog_remove(self):
        url = 'blog/remove'
        user1 = self.createUser('test1')
        user2 = self.createUser('test2')

        self.missingArguments(url, ['token', 'blogId'])

        # test invalid token
        response = self.makeRequest(url, {
            'token': 'aaaa',
            'blogId': 1
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # test non-existing blog id
        response = self.makeRequest(url, {
            'token': user1['token'],
            'blogId': 1
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # try to remove a post that doesn't belong to you
        post = self.addPost(user1)
        postId = post['post_id']
        response = self.makeRequest(url, {
            'token': user2['token'],
            'blogId': postId
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # remove a post and try to get it to confirm if it was removed
        response = self.makeRequest('/blog/get/{0}'.format(postId))
        self.assertEqual(response['success'], True)

        response = self.makeRequest(url, {
            'token': user1['token'],
            'blogId': postId
        })
        self.assertEqual(response['success'], True)

        response = self.makeRequest('/blog/get/{0}'.format(postId))
        self.assertEqual(response['success'], False)

    def test_blog_update(self):
        url = '/blog/update'
        user1 = self.createUser('test1')
        user2 = self.createUser('test2')
        title = 'The title.'
        body = 'The body message.'

        self.missingArguments(url, ['token', 'title', 'body', 'blogId'])

        # test invalid token
        response = self.makeRequest(url, {
            'token': 'aaaa',
            'blogId': 1,
            'title': title,
            'body': body
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # test non-existing blog id
        response = self.makeRequest(url, {
            'token': user1['token'],
            'blogId': 1,
            'title': title,
            'body': body
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # try to update a post that doesn't belong to you
        post = self.addPost(user1)
        postId = post['post_id']
        response = self.makeRequest(url, {
            'token': user2['token'],
            'blogId': postId,
            'title': title,
            'body': body
        })
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # test the 'title' and 'body' limits
        self.titleBodyTest(url, {
            'token': user1['token'],
            'blogId': postId
        })

        # update a post correctly
        newTitle = 'The new title!'
        newBody = 'The brand new body message!'
        response = self.makeRequest(url, {
            'token': user1['token'],
            'blogId': postId,
            'title': newTitle,
            'body': newBody
        })
        self.assertEqual(response['success'], True)

        # check if the changes were done
        self.postTest(postId, user1['username'], newTitle, newBody)

    def test_blog_username_getall(self):
        url = '/blog/{0}/getall'

        # test when username doesn't exist
        response = self.makeRequest(url.format('a'))
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # test with 0 posts
        user = self.createUser()
        username = user['username']
        response = self.makeRequest(url.format(username))
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # test with 1 post
        post = self.addPost(user)
        response = self.makeRequest(url.format(username))
        self.assertEqual(response['success'], True)
        self.assertEqual(len(response['posts_ids']), 1)
        self.assertEqual(int(response['posts_ids'][0]), post['post_id'])

    def test_blog_random(self):
        url = '/blog/random'

        # test with no posts yet
        response = self.makeRequest(url)
        self.assertEqual(response['success'], False)
        self.assertEqual('message' in response, True)

        # test with 1 post added
        user = self.createUser()
        post = self.addPost(user)
        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)
        self.assertEqual(response['post']['title'], post['title'])
        self.assertEqual(response['post']['body'], post['body'])
        self.assertEqual(response['post']['author'], user['username'])

    def test_blog_getall(self):
        url = '/blog/getall'

        # test with no posts yet
        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)
        self.assertEqual(len(response['posts_ids']), 0)

        # test with 1 post
        user = self.createUser()
        post1 = self.addPost(user)
        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)
        self.assertEqual(len(response['posts_ids']), 1)

        # test with 2
        post2 = self.addPost(user)
        response = self.makeRequest(url)
        self.assertEqual(response['success'], True)
        self.assertEqual(len(response['posts_ids']), 2)


if __name__ == '__main__':
    unittest.main()
