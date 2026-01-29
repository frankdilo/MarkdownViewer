# Mermaid Rendering Test

Use this file to validate Beautiful Mermaid rendering. It includes supported diagram types: flowchart, sequence, class, ER, and state.

## Flowchart

```mermaid
graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Do the thing]
    B -->|No| D[Stop]
    C --> E[Finish]
```

## Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant App
    participant API

    User->>App: Click "Render"
    App->>API: POST /render
    API-->>App: 200 OK + SVG
    App-->>User: Display diagram
```

## Class Diagram

```mermaid
classDiagram
    class Animal {
        +String name
        +Int age
        +eat()
    }
    class Dog {
        +String breed
        +bark()
    }
    class Cat {
        +Boolean indoor
        +meow()
    }
    Animal <|-- Dog
    Animal <|-- Cat
```

## ER Diagram

```mermaid
erDiagram
    CUSTOMER {
        int id PK
        string name
        string email
    }
    ORDER {
        int id PK
        date created_at
        int customer_id FK
    }
    CUSTOMER ||--o{ ORDER : places
```

## State Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Loading : start
    Loading --> Success : ok
    Loading --> Error : fail
    Error --> Idle : reset
    Success --> [*]
```
