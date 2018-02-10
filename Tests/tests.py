import unittest
import requests
import json
import os.path
from urllib.parse import urljoin

URL = 'http://localhost:8000/'


class TestBlog(unittest.TestCase):
    def test_user_create(self):
        pass

    def test_user_login(self):
        pass

    def test_user_remove(self):
        pass

    def test_user_change_password(self):
        pass

    def test_user_invalidate_tokens(self):
        pass

    def test_user_getall(self):
        r = requests.get(urljoin(URL, "/user/getall"))
        obj = json.loads(r.text)

        self.assertEqual(obj['success'], True)

    def test_user_random(self):
        pass

    def test_blog_add(self):
        pass

    def test_blog_get(self):
        pass

    def test_blog_remove(self):
        pass

    def test_blog_update(self):
        pass

    def test_blog_username_getall(self):
        pass

    def test_blog_random(self):
        pass

    def test_blog_getall(self):
        pass


if __name__ == '__main__':
    unittest.main()