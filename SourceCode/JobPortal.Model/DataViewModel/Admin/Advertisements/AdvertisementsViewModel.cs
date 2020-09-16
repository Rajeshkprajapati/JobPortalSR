using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Model.DataViewModel.Admin.Advertisements
{
    public class AdvertisementsViewModel
    {
        public int Id { get; set; }

        public string ImagePath { get; set; }

        public int Order { get; set; }

        public int Section { get; set; }

        public IFormFile ImageFile { get; set; }

        public string JobPage { get; set; }

    }
}
