using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Consware.Reimbursements.Api.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Reimbursements",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    EmployeeName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Category = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(8)", maxLength: 8, nullable: false),
                    RejectionReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DecidedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Reimbursements", x => x.Id);
                    table.CheckConstraint("CK_Reimbursements_State", "([Status] = 'Pending' AND [DecidedAtUtc] IS NULL AND [RejectionReason] IS NULL) OR ([Status] = 'Approved' AND [DecidedAtUtc] IS NOT NULL AND [RejectionReason] IS NULL) OR ([Status] = 'Rejected' AND [DecidedAtUtc] IS NOT NULL AND [RejectionReason] IS NOT NULL AND LEN([RejectionReason]) > 0)");
                });

            migrationBuilder.CreateIndex(
                name: "IX_Reimbursements_EmployeeName",
                table: "Reimbursements",
                column: "EmployeeName");

            migrationBuilder.CreateIndex(
                name: "IX_Reimbursements_Status",
                table: "Reimbursements",
                column: "Status");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Reimbursements");
        }
    }
}
