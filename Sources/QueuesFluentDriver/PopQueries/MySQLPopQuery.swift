import Foundation
import SQLKit
import Fluent

final class MySQLPop: PopQueryProtocol {
    // MySQL is a bit challenging since it doesn't support updating a table that is
    //  used in a subquery.
    // So we first select, then update, with the whole process wrapped in a transaction.
    func pop(db: Database, select: SQLExpression) -> EventLoopFuture<String?> {
        db.transaction { transaction in
            let database = transaction as! SQLDatabase
            var id: String?

            return database.execute(sql: select) { (row) -> Void in
                id = try? row.decode(column: "\(FieldKey.id)", as: String.self)
            }
            .flatMap {
                guard let id = id else {
                    return database.eventLoop.makeSucceededFuture(nil)
                }
                let updateQuery = database
                    .update(JobModel.schema)
                    .set(SQLColumn("\(FieldKey.state)"), to: SQLBind(QueuesFluentJobState.processing))
                    .set(SQLColumn("\(FieldKey.updatedAt)"), to: SQLBind(Date()))
                    .where(SQLColumn("\(FieldKey.id)"), .equal, SQLBind(id))
                    .where(SQLColumn("\(FieldKey.state)"), .equal, SQLBind(QueuesFluentJobState.pending))
                    .query
                return database.execute(sql: updateQuery) { (row) in }
                    .map { id }
            }
            
        }
    }
}
