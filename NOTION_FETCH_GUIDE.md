# Detailed Guide: Fetching Notion Database

This documentation provides the exact technical details needed to call the Notion API from your Swift application.

## 1. API Endpoint and Headers

Use these details to configure your `URLRequest` in Swift.

### Endpoint URL
- **Method**: `POST`
- **URL**: `https://api.notion.com/v1/data_sources/{DATA_SOURCE_ID}/query`

> [!IMPORTANT]
> This project uses the `data_sources` endpoint. Ensure your {DATA_SOURCE_ID} is correctly set in your Swift environment.

### Required HTTP Headers
| Key | Value | Description |
| :--- | :--- | :--- |
| `Authorization` | `Bearer {YOUR_NOTION_API_KEY}` | Your integration token. |
| `Content-Type` | `application/json` | Required for sending JSON bodies. |
| `Notion-Version` | `2026-03-11` | **Crucial**: The API behavior depends on this date. |

---

## 2. Query Body (Filter)

To fetch tasks that are "Not started" or "In progress", send the following JSON in the request body:

```json
{
  "filter": {
    "or": [
      {
        "property": "ステータス",
        "status": {
          "equals": "Not started"
        }
      },
      {
        "property": "ステータス",
        "status": {
          "equals": "In progress"
        }
      }
    ]
  }
}
```

---

## 3. JSON Response Structure

When parsing the response in Swift using `Codable`, look for these paths:

### Root Level
- `results`: An array of Page objects.
- `has_more`: Boolean (True if there are more items).
- `next_cursor`: String (Optional ID used to fetch the next page).

### Page Properties (`results[].properties`)
Here is how the specific fields are structured:

| Property Name | JSON Path | Type |
| :--- | :--- | :--- |
| **Title** | `properties.Name.title[0].plain_text` | String |
| **Status** | `properties.ステータス.status.name` | String |
| **Deadline**| `properties.締切.date.start` | String (ISO 8601) |
| **Estimate**| `properties.見積もり.select.name` | String |

---

## 4. Swift Implementation Tips

### URLRequest Setup
```swift
var request = URLRequest(url: URL(string: "https://api.notion.com/v1/data_sources/\(dataSourceID)/query")!)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("2026-03-11", forHTTPHeaderField: "Notion-Version")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
```

### Handling Pagination
If `has_more` is true, perform another `POST` request including the `"start_cursor": next_cursor` in your JSON body to get the next set of results.

### Why do we use these specific headers?
- **Notion-Version**: Notion updates its API structure frequently. By specifying `2026-03-11`, you ensure the API always returns data in the format your app expects, even if Notion releases a new version later.
- **Bearer Token**: This is like your "digital ID card" that proves to Notion you have permission to access the database.
