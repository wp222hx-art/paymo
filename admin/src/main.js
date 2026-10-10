import { createApp } from 'vue';
import { createRouter, createWebHashHistory } from 'vue-router';
import ElementPlus from 'element-plus';
import zhCn from 'element-plus/es/locale/lang/zh-cn';
import 'element-plus/dist/index.css';
import * as Icons from '@element-plus/icons-vue';
import App from './App.vue';
import Layout from './Layout.vue';
import { getToken } from './api';

const routes = [
  { path: '/login', component: () => import('./views/Login.vue'), meta: { public: true } },
  {
    path: '/',
    component: Layout,
    redirect: '/dashboard',
    children: [
      { path: 'dashboard', component: () => import('./views/Dashboard.vue'), meta: { title: '数据看板', icon: 'DataAnalysis' } },
      { path: 'categories', component: () => import('./views/Categories.vue'), meta: { title: '商品分类', icon: 'Menu' } },
      { path: 'products', component: () => import('./views/Products.vue'), meta: { title: '商品管理', icon: 'Goods' } },
      { path: 'orders', component: () => import('./views/Orders.vue'), meta: { title: '订单管理', icon: 'List' } },
      { path: 'commissions', component: () => import('./views/Commissions.vue'), meta: { title: '清偿金结算', icon: 'Money' } },
      { path: 'rules', component: () => import('./views/Rules.vue'), meta: { title: '返还倍率规则', icon: 'SetUp' } },
      { path: 'labor', component: () => import('./views/Labor.vue'), meta: { title: '微劳动', icon: 'Briefcase' } },
      { path: 'risk', component: () => import('./views/Risk.vue'), meta: { title: '风控 · 提现 · 内容', icon: 'Lock' } },
      { path: 'clearances', component: () => import('./views/Clearances.vue'), meta: { title: '清偿处理', icon: 'Finished' } },
      { path: 'bank', component: () => import('./views/Bank.vue'), meta: { title: '银行回函与证明', icon: 'Postcard' } },
      { path: 'users', component: () => import('./views/Users.vue'), meta: { title: '用户与账单', icon: 'User' } },
      { path: 'ledger', component: () => import('./views/Ledger.vue'), meta: { title: '财务分录', icon: 'Notebook' } },
      { path: 'settings', component: () => import('./views/Settings.vue'), meta: { title: '系统设置', icon: 'Setting' } },
    ],
  },
  { path: '/:p(.*)*', redirect: '/' },
];

const router = createRouter({ history: createWebHashHistory(), routes });
router.beforeEach((to) => (!to.meta.public && !getToken() ? '/login' : true));

const app = createApp(App);
for (const [k, c] of Object.entries(Icons)) app.component(k, c);
app.use(ElementPlus, { locale: zhCn }).use(router).mount('#app');

export { routes };
