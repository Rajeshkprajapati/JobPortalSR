using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class NotApprovedByAdmin : ApplicationException
    {
        public NotApprovedByAdmin(string message) : base(message)
        {

        }
        public NotApprovedByAdmin(string message, Exception exception) : base(message, exception)
        {

        }
    }
}
