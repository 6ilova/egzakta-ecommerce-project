# API Documentation

The Spring Boot backend uses **Spring Data REST** to automatically generate RESTful endpoints

All endpoints are served under the `/api` path. In production, Nginx reverse-proxies these requests from `http://192.168.56.10:8000/api/*` to the Spring Boot container.

## 1. Products Endpoint

**Endpoint:** `GET /api/products`

Retrieves a structured list of all products in the database.

**Example Request:**
```bash
curl http://192.168.56.10:8000/api/products?page=0&size=2
```

**Example Response:**
```json
{
  "_embedded": {
    "products": [
      {
        "sku": "BOOK-TECH-1000",
        "name": "Crash Course in Python",
        "description": "Learn Python at your own pace.",
        "unitPrice": 14.99,
        "imageUrl": "assets/images/products/books/book-luv2code-1000.png",
        "active": true,
        "unitsInStock": 100,
        "_links": {
          "self": {
            "href": "http://192.168.56.10:8090/api/products/1"
          },
          "product": {
            "href": "http://192.168.56.10:8090/api/products/1"
          },
          "category": {
            "href": "http://192.168.56.10:8090/api/products/1/category"
          }
        }
      }
    ]
  },
  "page": {
    "size": 2,
    "totalElements": 100,
    "totalPages": 50,
    "number": 0
  }
}
```

## 2. Product Categories Endpoint

**Endpoint:** `GET /api/product-category`

Retrieves a list of all product categories.

**Example Request:**
```bash
curl http://192.168.56.10:8000/api/product-category
```

## 3. Search Endpoints

### Find by Category ID
**Endpoint:** `GET /api/products/search/findByCategoryId?id={categoryId}`

### Find by Name
**Endpoint:** `GET /api/products/search/findByNameContaining?name={searchKeyword}`

