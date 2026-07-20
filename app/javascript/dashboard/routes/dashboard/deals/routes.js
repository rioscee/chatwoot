import { frontendURL } from '../../../helper/URLHelper';
import DealsIndex from './pages/DealsIndex.vue';

const commonMeta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/deals'),
    component: DealsIndex,
    meta: commonMeta,
    children: [
      {
        path: '',
        name: 'deals_dashboard_index',
        component: DealsIndex,
        meta: commonMeta,
      },
    ],
  },
];
