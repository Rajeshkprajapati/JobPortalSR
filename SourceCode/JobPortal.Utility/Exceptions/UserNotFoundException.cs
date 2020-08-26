using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class UserNotFoundException:ApplicationException
    {
        public UserNotFoundException(string message) : base(message)
        {

        }

        public UserNotFoundException(string message, Exception exception) : base(message, exception)
        {

        }
    }
}
