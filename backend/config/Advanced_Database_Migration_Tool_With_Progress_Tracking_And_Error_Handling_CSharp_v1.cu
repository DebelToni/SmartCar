using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Threading;

namespace DatabaseMigrationTool
{
    class Program
    {
        static string sourceConnectionString = "Data Source=SourceServer;Initial Catalog=SourceDB;Integrated Security=True";
        static string targetConnectionString = "Data Source=TargetServer;Initial Catalog=TargetDB;Integrated Security=True";
        static List<string> tablesToMigrate = new List<string> { "Customers", "Orders", "Products", "Suppliers" };
        static int totalTables;
        static int migratedTables = 0;
        static object lockObject = new object();
        static bool hasErrorOccurred = false;

        static void Main(string[] args)
        {
            Console.WriteLine("Starting database migration...");
            totalTables = tablesToMigrate.Count;
            foreach (var table in tablesToMigrate)
            {
                if (hasErrorOccurred)
                {
                    Console.WriteLine("Migration halted due to previous error.");
                    break;
                }
                try
                {
                    Console.WriteLine($"Migrating table: {table}...");
                    MigrateTable(table);
                    lock (lockObject)
                    {
                        migratedTables++;
                        Console.WriteLine($"Progress: {migratedTables}/{totalTables} tables migrated.");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error migrating table {table}: {ex.Message}");
                    hasErrorOccurred = true;
                }
            }
            if (!hasErrorOccurred)
            {
                Console.WriteLine("Database migration completed successfully.");
            }
            else
            {
                Console.WriteLine("Database migration terminated with errors.");
            }
        }

        static void MigrateTable(string tableName)
        {
            string query = $"SELECT * FROM {tableName}";
            using (SqlConnection sourceConn = new SqlConnection(sourceConnectionString))
            using (SqlConnection targetConn = new SqlConnection(targetConnectionString))
            {
                sourceConn.Open();
                targetConn.Open();
                using (SqlCommand cmd = new SqlCommand(query, sourceConn))
                {
                    using (SqlDataReader reader = cmd.ExecuteReader())
                    {
                        DataTable schemaTable = reader.GetSchemaTable();
                        List<string> columnNames = new List<string>();
                        foreach (DataRow row in schemaTable.Rows)
                        {
                            columnNames.Add(row["ColumnName"].ToString());
                        }
                        string insertCommandText = GenerateInsertCommand(tableName, columnNames);
                        using (SqlCommand insertCmd = new SqlCommand(insertCommandText, targetConn))
                        {
                            foreach (string col in columnNames)
                            {
                                insertCmd.Parameters.Add(new SqlParameter($"@{col}", SqlDbType.Variant));
                            }
                            int batchSize = 1000;
                            int currentBatchCount = 0;
                            List<Dictionary<string, object>> batchRows = new List<Dictionary<string, object>>();
                            while (reader.Read())
                            {
                                var rowData = new Dictionary<string, object>();
                                foreach (var col in columnNames)
                                {
                                    rowData[col] = reader[col];
                                }
                                batchRows.Add(rowData);
                                currentBatchCount++;
                                if (currentBatchCount >= batchSize)
                                {
                                    InsertBatch(insertCmd, batchRows, columnNames);
                                    batchRows.Clear();
                                    currentBatchCount = 0;
                                }
                            }
                            if (batchRows.Count > 0)
                            {
                                InsertBatch(insertCmd, batchRows, columnNames);
                            }
                        }
                    }
                }
            }
        }

        static string GenerateInsertCommand(string tableName, List<string> columns)
        {
            string cols = string.Join(", ", columns);
            string parameters = string.Join(", ", columns.ConvertAll(c => $"@{c}"));
            return $"INSERT INTO {tableName} ({cols}) VALUES ({parameters})";
        }

        static void InsertBatch(SqlCommand insertCmd, List<Dictionary<string, object>> batchRows, List<string> columns)
        {
            using (SqlTransaction transaction = insertCmd.Connection.BeginTransaction())
            {
                insertCmd.Transaction = transaction;
                try
                {
                    foreach (var row in batchRows)
                    {
                        for (int i = 0; i < columns.Count; i++)
                        {
                            insertCmd.Parameters[$"@{columns[i]}"].Value = row[columns[i]] ?? DBNull.Value;
                        }
                        insertCmd.ExecuteNonQuery();
                    }
                    transaction.Commit();
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error inserting batch: {ex.Message}");
                    transaction.Rollback();
                    throw;
                }
            }
        }
    }
}