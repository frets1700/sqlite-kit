extension SQLiteQuery {
    public struct Insert {
        public enum Values {
            case values([[Expression]])
            case select(Select)
            case defaults
        }
        
        public struct UpsertClause {
            public struct IndexedColumns {
                public struct Column {
                    public enum Value {
                    case column(String)
                    case expression(Expression)
                    }
                    public var value: Value
                    public var collate: String?
                    public var direction: Direction?
                }
                public var columns: [Column]
                public var predicate: Expression?
            }
            
            public enum Action {
                case nothing
                case update(SetValues)
            }
            
            public var indexedColumns: IndexedColumns?
            public var action: Action
        }
        
        public var with: WithClause?
        public var conflictResolution: ConflictResolution?
        public var table: TableName
        public var columns: [String]
        public var values: Values
        public var upsert: UpsertClause?
        
        public init(
            with: WithClause? = nil,
            conflictResolution: ConflictResolution? = nil,
            table: TableName,
            columns: [String] = [],
            values: Values = .defaults,
            upsert: UpsertClause? = nil
        ) {
            self.with = with
            self.conflictResolution = conflictResolution
            self.table = table
            self.columns = columns
            self.values = values
            self.upsert = upsert
        }
    }
}


extension SQLiteSerializer {
    func serialize(_ insert: SQLiteQuery.Insert, _ binds: inout [SQLiteData]) -> String {
        var sql: [String] = []
        if let with = insert.with {
            sql.append(serialize(with, &binds))
        }
        sql.append("INSERT")
        if let conflictResolution = insert.conflictResolution {
            sql.append("OR")
            sql.append(serialize(conflictResolution))
        }
        sql.append("INTO")
        sql.append(serialize(insert.table))
        if !insert.columns.isEmpty {
            sql.append(serialize(columns: insert.columns))
        }
        sql.append(serialize(insert.values, &binds))
        if let upsert = insert.upsert {
            sql.append(serialize(upsert, &binds))
        }
        return sql.joined(separator: " ")
    }
    
    func serialize(_ values: SQLiteQuery.Insert.Values, _ binds: inout [SQLiteData]) -> String {
        switch values {
        case .defaults: return "DEFAULT VALUES"
        case .select(let select): return serialize(select, &binds)
        case .values(let values):
            return "VALUES " + values.map {
                return "(" + $0.map { serialize($0, &binds) }.joined(separator: ", ") + ")"
            }.joined(separator: ", ")
        }
    }
    
    func serialize(_ upsert: SQLiteQuery.Insert.UpsertClause, _ binds: inout [SQLiteData]) -> String {
        var sql: [String] = []
        sql.append("ON CONFLICT")
        if let indexed = upsert.indexedColumns {
            sql.append(serialize(indexed, &binds))
        }
        sql.append("DO")
        sql.append(serialize(upsert.action, &binds))
        return sql.joined(separator: " ")
    }
    
    func serialize(_ action: SQLiteQuery.Insert.UpsertClause.Action, _ binds: inout [SQLiteData]) -> String {
        var sql: [String] = []
        switch action {
        case .nothing: sql.append("NOTHING")
        case .update(let setValues):
            sql.append("UPDATE")
            sql.append(serialize(setValues, &binds))
        }
        return sql.joined(separator: " ")
    }
    
    func serialize(_ indexed: SQLiteQuery.Insert.UpsertClause.IndexedColumns, _ binds: inout [SQLiteData]) -> String {
        var sql: [String] = []
        sql.append("(" + indexed.columns.map { serialize($0, &binds) }.joined(separator: ", ") + ")")
        if let predicate = indexed.predicate {
            sql.append("WHERE")
            sql.append(serialize(predicate, &binds))
        }
        return sql.joined(separator: " ")
    }
    
    func serialize(_ column: SQLiteQuery.Insert.UpsertClause.IndexedColumns.Column, _ binds: inout [SQLiteData]) -> String {
        var sql: [String] = []
        switch column.value {
        case .column(let string): sql.append(escapeString(string))
        case .expression(let expr): sql.append(serialize(expr, &binds))
        }
        if let collate = column.collate {
            sql.append("COLLATE")
            sql.append(collate)
        }
        if let direction = column.direction {
            sql.append(serialize(direction))
        }
        return sql.joined(separator: " ")
    }
}
