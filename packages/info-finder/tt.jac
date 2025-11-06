node Post {
    has content: str;
    has author: str;
}

walker create_post {
    has content: str, author: str;

    with entry {
        new_post = Post(content=self.content, author=self.author);
        // 'here' is the current node (the root).
        here ++> new_post;
        
        // Jac objects automatically get a unique 'id' property.
        report {"id": new_post.id, "status": "posted"};
    }
}