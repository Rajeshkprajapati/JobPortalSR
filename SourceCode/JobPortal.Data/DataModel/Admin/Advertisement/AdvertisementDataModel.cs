using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Data.DataModel.Admin.Advertisement
{
    public class AdvertisementDataModel
    {
        public int Id { get; set; }
        public string ImagePath { get; set; }

        public int Order { get; set; }

        public int Section { get; set; }
    }
}
