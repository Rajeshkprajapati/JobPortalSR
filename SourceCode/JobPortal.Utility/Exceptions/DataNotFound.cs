﻿using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class DataNotFound: ApplicationException
    {
        public DataNotFound(string message) : base(message)
        {

        }

        public DataNotFound(string message, Exception exception) : base(message, exception)
        {

        }
    }
}
