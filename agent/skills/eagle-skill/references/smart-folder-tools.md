# Smart Folder Tools

Smart folder management - create, update, delete smart folders with filter conditions

## smart_folder_create

Create smart folders with filter conditions to automatically organize items. Supports custom colors, descriptions, and parent hierarchy.

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| smartFolders | object[] | Yes | Array of smart folders to create |

### Example

```bash
node scripts/eagle-api-cli.js call smart_folder_create --json '{"smartFolders":[]}'
```

## smart_folder_get

Retrieve smart folders by ID or get all smart folders. Supports hierarchy view and detail level control. Use fullDetails to include filter conditions.

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| id | string | No | Single smart folder ID |
| ids | string[] | No | Array of smart folder IDs |
| getAllHierarchy | boolean | No | Return all smart folders with full hierarchy |
| fullDetails | boolean | No | Return complete smart folder information including conditions |

### Example

```bash
node scripts/eagle-api-cli.js call smart_folder_get
```

## smart_folder_update

Update smart folder properties including name, description, icon color, filter conditions, and parent. Supports shared parameters at top level that apply to all folders - individual folders can override these. Efficient for batch updates.

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| name | string | No | Shared name applied to all folders (can be overridden per folder) |
| description | string | No | Shared description applied to all folders (can be overridden per folder) |
| iconColor | "red" \| "orange" \| "yellow" \| "green" \| "aqua" \| "blue" \| "purple" \| "pink" \| "none" | No | Shared icon color applied to all folders (can be overridden per folder). Use predefined colors or 'none' to clear |
| conditions | object[] | No | Array of condition groups. Each group has a "match" ("AND"/"OR") and a "rules" array. Example: [{ "match": "OR", "rules": [{ "property": "type", "method": "equal", "value": "jpg" }, { "property": "type", "method": "equal", "value": "png" }] }] |
| parent | string | No | Shared parent folder ID applied to all folders (null for root, can be overridden per folder) |
| smartFolders | object[] | Yes | Array of smart folders to update, each containing id and optional override properties |

### Example

```bash
node scripts/eagle-api-cli.js call smart_folder_update --json '{"smartFolders":[]}'
```

## smart_folder_delete

Delete smart folders by ID. This removes the smart folder and its filter conditions but does not delete the actual items. Use carefully as this operation cannot be undone.

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| ids | string[] | Yes | Array of smart folder IDs to delete |

### Example

```bash
node scripts/eagle-api-cli.js call smart_folder_delete --json '{"ids":[]}'
```

## smart_folder_get_items

Get items that match a smart folder's filter conditions. Returns the library items that would appear in the smart folder. Supports sorting and field selection.

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| id | string | Yes | Smart folder ID |
| orderBy | string | No | Sort order for results |
| fields | string[] | No | Specific fields to include in returned items |

### Example

```bash
node scripts/eagle-api-cli.js call smart_folder_get_items --json '{"id":"<string>"}'
```

## smart_folder_get_rules

Get available filter rule schemas for smart folders. Returns the supported properties, methods, value types, and options that can be used to build filter conditions for smart_folder_create and smart_folder_update.

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|

### Example

```bash
node scripts/eagle-api-cli.js call smart_folder_get_rules
```
