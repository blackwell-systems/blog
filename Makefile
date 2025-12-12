.PHONY: build serve stop clean

build:
	docker build -t blog-hugo .

serve: build
	docker run --rm -v $$(pwd):/src -p 1313:1313 --name blog-hugo blog-hugo

serve-bg: build
	docker run -d --rm -v $$(pwd):/src -p 1313:1313 --name blog-hugo blog-hugo

stop:
	docker stop blog-hugo 2>/dev/null || true

clean:
	docker rmi blog-hugo 2>/dev/null || true
