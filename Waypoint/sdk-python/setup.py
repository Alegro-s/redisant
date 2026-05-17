from setuptools import setup, find_packages

setup(
    name="waypoint-metrics",
    version="0.1.0",
    packages=find_packages(),
    install_requires=["requests>=2.25.0"],
    author="Your Name",
    description="Python client for Waypoint Metrics",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    url="https://github.com/Alegro-s/WaypointMetrics",
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.7",
)