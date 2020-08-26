using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class NotApprovedByAdminException : ApplicationException
    {
        public NotApprovedByAdminException(string message) : base(message)
        {

        }
        public NotApprovedByAdminException(string message, Exception exception) : base(message, exception)
        {

        }
    }
}
