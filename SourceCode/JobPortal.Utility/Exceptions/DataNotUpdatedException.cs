﻿using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class DataNotUpdatedException:ApplicationException
    {
        public DataNotUpdatedException(string message) : base(message)
        {

        }

        public DataNotUpdatedException(string message, Exception exception) : base(message, exception)
        {

        }
    }
}
