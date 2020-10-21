using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class InvalidRoleException : ApplicationException
    {
        public InvalidRoleException(string message) : base(message)
        {

        }
        public InvalidRoleException(string message, Exception exception) : base(message)
        {

        }
    }
}
