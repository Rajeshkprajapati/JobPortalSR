using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;

namespace JobPortal.Data.Repositories.Admin
{
    public class NotificationRepository: INotificationRepository
    {
        private readonly string connectionString;
        public NotificationRepository(IConfiguration configuration)
        {
            connectionString = configuration["ConnectionStrings:NassComJobPortalDB"];
        }

        public DataSet GetNotificationsCounter()
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetNotificationsCounter"
                            );
                    if (null != result)
                    {
                        return result;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Notifications not found to display.");
        }
    }
}
