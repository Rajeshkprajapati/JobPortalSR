using Microsoft.AspNetCore.SignalR;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace JobPortal.Web.Controllers.Hubs
{
    public class ActiveUsers : Hub
    {
        private static int _userCount = 50;

        public void ActiveUserCount()
        {
            Clients.All.SendAsync("UserCount", _userCount);
        }

        public override async Task OnConnectedAsync()
        {
            _userCount++;
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception exception)
        {
            --_userCount;
            await base.OnDisconnectedAsync(exception);
        }
    }
}
