from locust import HttpUser, task, between

class WebsiteUser(HttpUser):
    wait_time = between(1, 5)

    @task(3)
    def normal_query(self):
        """Simulates the most common user action: a fast, normal query."""
        self.client.get("/query/normal")

    @task(1)
    def wait_query(self):
        """Simulates an infrequent but heavy action, like generating a report."""
        self.client.get("/query/wait")

    @task(2)
    def missing_index_query(self):
        """Simulates a user performing a poorly optimized search."""
        self.client.get("/query/missing_index")
