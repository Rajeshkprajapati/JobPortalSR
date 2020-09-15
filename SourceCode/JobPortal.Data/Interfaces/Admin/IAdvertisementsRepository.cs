using JobPortal.Data.DataModel.Admin.Advertisement;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Admin
{
    public interface IAdvertisementsRepository
    {
        DataTable GetAllData();
        bool AddAds(AdvertisementDataModel model);
        bool UpdateAds(AdvertisementDataModel model,int userid);
        bool DeleteAds(int adId);
    }
}
